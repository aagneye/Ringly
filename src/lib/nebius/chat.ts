import type { ChatCompletionMessageParam, ChatCompletionTool } from 'openai/resources/chat/completions';
import { getNebiusClient } from './client';
import { modelForTask, tierForTask, type RinglyTask } from './models';
import type { ModelTrace, TraceCollector } from './trace';

export interface ChatOptions {
  task: RinglyTask;
  messages: ChatCompletionMessageParam[];
  temperature?: number;
  maxTokens?: number;
  /** JSON Schema for strict structured output. */
  jsonSchema?: { name: string; schema: Record<string, unknown> };
  /** Tool definitions, when the model is allowed to choose actions. */
  tools?: ChatCompletionTool[];
  /** Overrides the tier mapping. Used by the audio path when Omni is absent. */
  modelOverride?: string;
  collector?: TraceCollector;
}

export interface ChatResult {
  content: string;
  toolCalls: ResolvedToolCall[];
  trace: ModelTrace;
  finishReason: string | null;
}

export interface ResolvedToolCall {
  id: string;
  name: string;
  /** Raw argument string as returned by the model, before validation. */
  rawArguments: string;
}

/**
 * The single door every Nemotron call goes through.
 *
 * Centralising it buys three things the product depends on: a trace for the UI
 * strip, one consistent place to attach the tier-selection rule, and one place
 * where a transport failure becomes a typed error rather than an unhandled
 * rejection inside a route handler.
 */
export async function chat(options: ChatOptions): Promise<ChatResult> {
  const model = options.modelOverride ?? modelForTask(options.task);
  const tier = tierForTask(options.task);
  const client = getNebiusClient();
  const startedAt = Date.now();

  try {
    const response = await client.chat.completions.create({
      model,
      messages: options.messages,
      temperature: options.temperature ?? 0.2,
      max_tokens: options.maxTokens ?? 1024,
      ...(options.jsonSchema
        ? {
            response_format: {
              type: 'json_schema' as const,
              json_schema: {
                name: options.jsonSchema.name,
                schema: options.jsonSchema.schema,
                strict: true,
              },
            },
          }
        : {}),
      ...(options.tools ? { tools: options.tools, tool_choice: 'auto' as const } : {}),
    });

    const choice = response.choices[0];
    const message = choice?.message;

    const trace: ModelTrace = {
      task: options.task,
      tier,
      model,
      promptTokens: response.usage?.prompt_tokens ?? 0,
      completionTokens: response.usage?.completion_tokens ?? 0,
      latencyMs: Date.now() - startedAt,
    };
    options.collector?.record(trace);

    return {
      content: message?.content ?? '',
      toolCalls: normaliseToolCalls(message),
      trace,
      finishReason: choice?.finish_reason ?? null,
    };
  } catch (error) {
    const trace: ModelTrace = {
      task: options.task,
      tier,
      model,
      promptTokens: 0,
      completionTokens: 0,
      latencyMs: Date.now() - startedAt,
      failed: true,
      error: error instanceof Error ? error.message : String(error),
    };
    options.collector?.record(trace);
    throw new ChatCallError(options.task, model, error);
  }
}

/** Flatten the SDK's tool call shape into something validation can consume. */
function normaliseToolCalls(message: unknown): ResolvedToolCall[] {
  if (!message || typeof message !== 'object') return [];
  const calls = (message as { tool_calls?: unknown }).tool_calls;
  if (!Array.isArray(calls)) return [];

  return calls.flatMap((call): ResolvedToolCall[] => {
    if (!call || typeof call !== 'object') return [];
    const typed = call as {
      id?: string;
      function?: { name?: string; arguments?: string };
    };
    const name = typed.function?.name;
    if (!name) return [];
    return [
      {
        id: typed.id ?? name,
        name,
        rawArguments: typed.function?.arguments ?? '{}',
      },
    ];
  });
}

export class ChatCallError extends Error {
  constructor(
    readonly task: RinglyTask,
    readonly model: string,
    readonly cause: unknown,
  ) {
    const detail = cause instanceof Error ? cause.message : String(cause);
    super(`Nemotron call failed for task "${task}" on ${model}: ${detail}`);
    this.name = 'ChatCallError';
  }
}
