import type { z } from 'zod';
import type { ActionSource, ActionStatus } from '@/lib/db/schema/enums';

/**
 * The contract every agent tool implements.
 *
 * Two properties matter more than the rest:
 *
 * `reversible` encodes the trust model. A reversible tool runs the moment the
 * model asks for it; an irreversible one is staged and waits for a human tap.
 * Putting that flag on the tool definition rather than in the runner means a new
 * tool cannot accidentally be given send-without-asking power by omission.
 *
 * `parameters` is duplicated as a zod schema and a JSON Schema on purpose. The
 * JSON Schema goes on the wire to the model; zod validates what comes back.
 * Deriving one from the other sounds tidier but produces schemas strict mode
 * rejects, and a model arguing with the wire format is not worth the elegance.
 */
export interface ToolDefinition<TArgs = unknown> {
  name: string;
  /** Shown to the model. This text does most of the work of tool selection. */
  description: string;
  parameters: z.ZodType<TArgs>;
  jsonSchema: Record<string, unknown>;
  /** False means the action is staged for approval instead of applied. */
  reversible: boolean;
  execute: (args: TArgs, context: ToolContext) => Promise<ToolOutcome>;
}

export interface ToolContext {
  /** Groups every action from one agent run. */
  runId: string;
  /** Injected rather than read from the clock, so runs are reproducible. */
  now: Date;
  /** Note the run originated from, when there is one. */
  noteId: string | null;
  /** Deal the run is centred on, resolved before tools execute. */
  dealId: string | null;
  contactId: string | null;
  source: ActionSource;
  userName: string;
  timezone: string;
}

export interface ToolOutcome {
  status: ActionStatus;
  /** One sentence for the activity feed: "Moved Priya to Proposal". */
  summary: string;
  /** Rows the tool created, so the response can return them without a re-read. */
  created?: Record<string, unknown>;
  error?: string;
}

/** Shape handed to the OpenAI-compatible `tools` parameter. */
export interface WireTool {
  type: 'function';
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
}

/** Project a tool definition onto the wire format the model expects. */
export function toWireTool(tool: ToolDefinition<never>): WireTool {
  return {
    type: 'function',
    function: {
      name: tool.name,
      description: tool.description,
      parameters: tool.jsonSchema,
    },
  };
}
