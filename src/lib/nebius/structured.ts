import { z } from 'zod';
import type { ChatCompletionMessageParam } from 'openai/resources/chat/completions';
import { chat } from './chat';
import { parseJsonLoose } from './json';
import type { RinglyTask } from './models';
import type { TraceCollector } from './trace';

export interface StructuredOptions<T extends z.ZodType> {
  task: RinglyTask;
  schema: T;
  /** JSON Schema sent to the model. Kept separate because zod-to-json-schema
   * output is not always accepted by strict mode, so callers hand-write the
   * wire schema and keep zod for validation. */
  wireSchema: { name: string; schema: Record<string, unknown> };
  system: string;
  user: string;
  temperature?: number;
  maxTokens?: number;
  collector?: TraceCollector;
}

export interface StructuredResult<T> {
  data: T;
  /** True when strict mode failed and the loose parser salvaged the output. */
  recovered: boolean;
}

/**
 * Ask a model for JSON and come back with a validated object or a thrown error.
 *
 * Two layers of defence, because a demo cannot afford a parse crash: the
 * request asks for strict `json_schema` output, and whatever comes back is run
 * through the loose extractor before zod validates it. If the model returned a
 * fenced block or a `<think>` preamble despite strict mode, we still succeed
 * and flag it as recovered.
 */
export async function structured<T extends z.ZodType>(
  options: StructuredOptions<T>,
): Promise<StructuredResult<z.infer<T>>> {
  const messages: ChatCompletionMessageParam[] = [
    { role: 'system', content: options.system },
    { role: 'user', content: options.user },
  ];

  const result = await chat({
    task: options.task,
    messages,
    temperature: options.temperature ?? 0.1,
    maxTokens: options.maxTokens ?? 1024,
    jsonSchema: options.wireSchema,
    collector: options.collector,
  });

  let recovered = false;
  let candidate: unknown;

  try {
    candidate = JSON.parse(result.content);
  } catch {
    candidate = parseJsonLoose(result.content);
    recovered = true;
  }

  if (candidate === null || candidate === undefined) {
    throw new StructuredOutputError(options.task, result.content);
  }

  const parsed = options.schema.safeParse(candidate);
  if (!parsed.success) {
    throw new StructuredOutputError(
      options.task,
      result.content,
      z.prettifyError ? z.prettifyError(parsed.error) : parsed.error.message,
    );
  }

  return { data: parsed.data, recovered };
}

export class StructuredOutputError extends Error {
  constructor(
    readonly task: RinglyTask,
    readonly rawOutput: string,
    readonly validationDetail?: string,
  ) {
    const preview = rawOutput.slice(0, 300);
    super(
      `Task "${task}" did not return usable JSON.` +
        (validationDetail ? ` Validation: ${validationDetail}.` : '') +
        ` Raw output began: ${preview}`,
    );
    this.name = 'StructuredOutputError';
  }
}
