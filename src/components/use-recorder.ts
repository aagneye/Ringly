'use client';

import { useCallback, useEffect, useRef, useState } from 'react';

/**
 * Microphone recording, wrapped so the UI never touches MediaRecorder directly.
 *
 * Browser reality this hook absorbs:
 *
 *   - Codec support differs. Chrome and Firefox produce webm/opus; Safari
 *     produces mp4. Passing an unsupported mimeType to MediaRecorder throws, so
 *     the list is probed rather than assumed.
 *   - Permission denial and "no microphone attached" are different failures that
 *     need different wording, and the DOMException name is the only way to tell.
 *   - The audio tracks must be stopped explicitly. Without it the browser's
 *     recording indicator stays lit after the user has finished, which reads as a
 *     privacy problem even though nothing is being captured.
 *   - Unmounting mid-recording has to release the device, or the tab holds the
 *     microphone until it is closed.
 */

const CANDIDATE_TYPES = [
  'audio/webm;codecs=opus',
  'audio/webm',
  'audio/ogg;codecs=opus',
  'audio/mp4',
  'audio/mpeg',
];

export type RecorderState = 'idle' | 'requesting' | 'recording' | 'stopping' | 'error';

export interface Recording {
  blob: Blob;
  mimeType: string;
  durationSeconds: number;
}

export interface UseRecorderResult {
  state: RecorderState;
  /** Seconds elapsed, updated roughly ten times a second. */
  elapsed: number;
  /** 0-1 input level, for the waveform. */
  level: number;
  error: string | null;
  supported: boolean;
  start: () => Promise<void>;
  stop: () => Promise<Recording | null>;
  cancel: () => void;
}

/** Pick the first container the browser will actually accept. */
export function pickMimeType(): string {
  if (typeof MediaRecorder === 'undefined') return '';
  for (const type of CANDIDATE_TYPES) {
    if (MediaRecorder.isTypeSupported(type)) return type;
  }
  return '';
}

export function useRecorder(maxSeconds = 120): UseRecorderResult {
  const [state, setState] = useState<RecorderState>('idle');
  const [elapsed, setElapsed] = useState(0);
  const [level, setLevel] = useState(0);
  const [error, setError] = useState<string | null>(null);
  // A static feature check, not a subscription to something that changes over
  // the component's life, so it is read once at init rather than via an effect.
  const [supported] = useState(
    () =>
      typeof navigator !== 'undefined' &&
      typeof navigator.mediaDevices?.getUserMedia === 'function' &&
      typeof MediaRecorder !== 'undefined',
  );

  const recorderRef = useRef<MediaRecorder | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const startedAtRef = useRef<number>(0);
  const tickRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const audioContextRef = useRef<AudioContext | null>(null);
  const frameRef = useRef<number | null>(null);

  const teardown = useCallback(() => {
    if (tickRef.current) {
      clearInterval(tickRef.current);
      tickRef.current = null;
    }
    if (frameRef.current !== null) {
      cancelAnimationFrame(frameRef.current);
      frameRef.current = null;
    }
    if (audioContextRef.current) {
      void audioContextRef.current.close().catch(() => undefined);
      audioContextRef.current = null;
    }
    // Releasing the tracks is what turns the browser's recording dot off.
    streamRef.current?.getTracks().forEach((track) => track.stop());
    streamRef.current = null;
    recorderRef.current = null;
    setLevel(0);
  }, []);

  useEffect(() => teardown, [teardown]);

  const startMeter = useCallback((stream: MediaStream) => {
    try {
      const AudioContextCtor =
        window.AudioContext ??
        (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (!AudioContextCtor) return;

      const context = new AudioContextCtor();
      audioContextRef.current = context;
      const source = context.createMediaStreamSource(stream);
      const analyser = context.createAnalyser();
      analyser.fftSize = 512;
      source.connect(analyser);

      const buffer = new Uint8Array(analyser.frequencyBinCount);

      const sample = () => {
        analyser.getByteTimeDomainData(buffer);
        let sum = 0;
        for (let i = 0; i < buffer.length; i += 1) {
          const centred = ((buffer[i] ?? 128) - 128) / 128;
          sum += centred * centred;
        }
        const rms = Math.sqrt(sum / buffer.length);
        // Scale up: speech RMS sits low, and an unscaled bar looks broken.
        setLevel(Math.min(1, rms * 3.2));
        frameRef.current = requestAnimationFrame(sample);
      };

      frameRef.current = requestAnimationFrame(sample);
    } catch {
      // A missing analyser only costs the waveform, so recording continues.
    }
  }, []);

  const start = useCallback(async () => {
    setError(null);
    setElapsed(0);
    chunksRef.current = [];
    setState('requesting');

    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        },
      });
      streamRef.current = stream;

      const mimeType = pickMimeType();
      const recorder = new MediaRecorder(stream, mimeType ? { mimeType } : undefined);
      recorderRef.current = recorder;

      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) chunksRef.current.push(event.data);
      };

      recorder.start(250);
      startedAtRef.current = Date.now();
      setState('recording');
      startMeter(stream);

      tickRef.current = setInterval(() => {
        const seconds = (Date.now() - startedAtRef.current) / 1000;
        setElapsed(seconds);
        if (seconds >= maxSeconds && recorderRef.current?.state === 'recording') {
          recorderRef.current.stop();
        }
      }, 100);
    } catch (caught) {
      teardown();
      setState('error');
      setError(describeMicError(caught));
    }
  }, [maxSeconds, startMeter, teardown]);

  const stop = useCallback(async (): Promise<Recording | null> => {
    const recorder = recorderRef.current;
    if (!recorder || recorder.state === 'inactive') {
      teardown();
      setState('idle');
      return null;
    }

    setState('stopping');

    const durationSeconds = (Date.now() - startedAtRef.current) / 1000;
    const mimeType = recorder.mimeType || pickMimeType() || 'audio/webm';

    const blob = await new Promise<Blob>((resolve) => {
      recorder.addEventListener(
        'stop',
        () => resolve(new Blob(chunksRef.current, { type: mimeType })),
        { once: true },
      );
      recorder.stop();
    });

    teardown();
    setState('idle');

    if (blob.size === 0) {
      setError('Nothing was recorded. Check your microphone and try again.');
      return null;
    }

    return { blob, mimeType, durationSeconds };
  }, [teardown]);

  const cancel = useCallback(() => {
    const recorder = recorderRef.current;
    if (recorder && recorder.state !== 'inactive') {
      recorder.stop();
    }
    chunksRef.current = [];
    teardown();
    setElapsed(0);
    setState('idle');
  }, [teardown]);

  return { state, elapsed, level, error, supported, start, stop, cancel };
}

/** Turn a getUserMedia rejection into something a user can act on. */
export function describeMicError(caught: unknown): string {
  if (typeof DOMException !== 'undefined' && caught instanceof DOMException) {
    switch (caught.name) {
      case 'NotAllowedError':
      case 'SecurityError':
        return 'Microphone access was blocked. Allow it in your browser settings and try again.';
      case 'NotFoundError':
      case 'DevicesNotFoundError':
        return 'No microphone was found. Plug one in, or type the note instead.';
      case 'NotReadableError':
      case 'TrackStartError':
        return 'Your microphone is in use by another app. Close it and try again.';
      case 'OverconstrainedError':
        return 'Your microphone does not support the requested settings.';
      default:
        return `Could not start recording: ${caught.name}.`;
    }
  }
  return caught instanceof Error ? caught.message : 'Could not start recording.';
}
