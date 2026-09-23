import type { ModelId, ModelTier, RinglyTask } from './models';

/**
 * A single model call, recorded so the UI can show which Nemotron tier did
 * what and at what cost. This is a product feature, not just telemetry: the
 * demo depends on a judge being able to watch Lightning, Super and Ultra each
 * take the part of the job they are suited to.
 */
export interface ModelTrace {
  task: RinglyTask;
  tier: ModelTier;
  model: ModelId | string;
  promptTokens: number;
  completionTokens: number;
  latencyMs: number;
  /** Set when the call failed and a fallback produced the result instead. */
  failed?: boolean;
  /** Short reason, present only when `failed` is true. */
  error?: string;
}

/** Aggregate of several traces, for the run summary shown after a memo. */
export interface TraceSummary {
  traces: ModelTrace[];
  totalPromptTokens: number;
  totalCompletionTokens: number;
  totalLatencyMs: number;
  /** Wall-clock duration of the whole run, which is less than the sum when
   * calls were issued concurrently. */
  wallClockMs: number;
}

/** Collects traces across one logical run (one memo, one briefing, one review). */
export class TraceCollector {
  private readonly traces: ModelTrace[] = [];
  private readonly startedAt = Date.now();

  record(trace: ModelTrace): void {
    this.traces.push(trace);
  }

  all(): readonly ModelTrace[] {
    return this.traces;
  }

  summarise(): TraceSummary {
    return {
      traces: [...this.traces],
      totalPromptTokens: this.traces.reduce((sum, t) => sum + t.promptTokens, 0),
      totalCompletionTokens: this.traces.reduce((sum, t) => sum + t.completionTokens, 0),
      totalLatencyMs: this.traces.reduce((sum, t) => sum + t.latencyMs, 0),
      wallClockMs: Date.now() - this.startedAt,
    };
  }
}
