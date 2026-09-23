import { describe, it, expect } from 'vitest';
import { audioFormatFromMime, TranscriptionUnavailableError } from '@/lib/nebius/transcribe';

describe('audioFormatFromMime', () => {
  it('maps the Chrome and Firefox default recording type', () => {
    expect(audioFormatFromMime('audio/webm;codecs=opus')).toBe('webm');
  });

  it('maps plain webm', () => {
    expect(audioFormatFromMime('audio/webm')).toBe('webm');
  });

  it('maps ogg', () => {
    expect(audioFormatFromMime('audio/ogg;codecs=opus')).toBe('ogg');
  });

  it('maps the Safari and iOS recording type', () => {
    expect(audioFormatFromMime('audio/mp4')).toBe('mp4');
  });

  it('maps m4a', () => {
    expect(audioFormatFromMime('audio/x-m4a')).toBe('mp4');
  });

  it('maps mpeg and mp3 to mp3', () => {
    expect(audioFormatFromMime('audio/mpeg')).toBe('mp3');
    expect(audioFormatFromMime('audio/mp3')).toBe('mp3');
  });

  it('maps wav', () => {
    expect(audioFormatFromMime('audio/wav')).toBe('wav');
  });

  it('is case insensitive', () => {
    expect(audioFormatFromMime('AUDIO/WEBM')).toBe('webm');
  });

  it('falls back to webm for an unrecognised type', () => {
    expect(audioFormatFromMime('application/octet-stream')).toBe('webm');
  });

  it('falls back to webm for an empty string', () => {
    expect(audioFormatFromMime('')).toBe('webm');
  });
});

describe('TranscriptionUnavailableError', () => {
  it('reports every provider that was attempted', () => {
    const error = new TranscriptionUnavailableError([
      'Nemotron Omni chat → 404 model not found',
      'audio transcriptions endpoint → 404 not found',
    ]);
    expect(error.message).toContain('Nemotron Omni chat');
    expect(error.message).toContain('audio transcriptions endpoint');
  });

  it('suggests typing the note as a way forward', () => {
    expect(new TranscriptionUnavailableError([]).message).toContain('Type the note instead');
  });

  it('keeps the attempt list available for logging', () => {
    const error = new TranscriptionUnavailableError(['a', 'b']);
    expect(error.attempts).toEqual(['a', 'b']);
  });
});
