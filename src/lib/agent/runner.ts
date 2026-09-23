import { getDb } from '@/lib/db';
import { agentActions } from '@/lib/db/schema/agent-actions';
import { modelTraces } from '@/lib/db/schema/model-traces';
import { findTool } from './tools';
import { parseJsonLoose } from '@/lib/nebius/json';
import type { ToolContext, ToolOutcome } from './tools/types';
import type { ResolvedToolCall } from '@/lib/nebius/chat';
import type { ModelTrace } from '@/lib/nebius/trace';

/**
 * Executing the plan the model produced.
 *
 * Three properties this runner guarantees, each learned the hard way:
 *
 * 1. Nothing runs unvalidated. A model can name a tool that does not exist or
 *    hand it arguments of the wrong shape; both become a recorded failure rather
 *    than a thrown exception that loses the other four actions in the batch.
 *
 * 2. One bad tool cannot take down the run. Each call is isolated, so a failed
 *    calendar write still leaves the deal update and the reminder in place. A
 *    partial success is a far better outcome for the user than an all-or-nothing
 *    rollback.
 *
 * 3. Every outcome is persisted before it is reported. The UI reads from
 *    `agent_actions`, so it is incapable of claiming an action that did not
 *    actually happen.
 */

export interface ExecutedAction {
  tool: string;
  status: ToolOutcome['status'];
  summary: string;
  created?: Record<string, unknown>;
  error?: string;
}

export interface RunReport {
  runId: string;
  actions: ExecutedAction[];
  /** Actions that landed immediately. */
  applied: ExecutedAction[];
  /** Actions staged for a human tap. */
  awaitingApproval: ExecutedAction[];
  failed: ExecutedAction[];
}

/** Validate and execute a batch of tool calls, recording each outcome. */
export async function executeToolCalls(
  calls: readonly ResolvedToolCall[],
  context: ToolContext,
): Promise<RunReport> {
  const actions: ExecutedAction[] = [];

  for (const call of calls) {
    actions.push(await executeOne(call, context));
  }

  return {
    runId: context.runId,
    actions,
    applied: actions.filter((action) => action.status === 'applied'),
    awaitingApproval: actions.filter((action) => action.status === 'awaiting_approval'),
    failed: actions.filter((action) => action.status === 'failed'),
  };
}

async function executeOne(
  call: ResolvedToolCall,
  context: ToolContext,
): Promise<ExecutedAction> {
  const tool = findTool(call.name);

  if (!tool) {
    return record(
      {
        tool: call.name,
        status: 'failed',
        summary: `Skipped an unknown action "${call.name}"`,
        error: `No tool named ${call.name} is registered.`,
      },
      call,
      context,
    );
  }

  // Models occasionally send arguments as a JSON string wrapped in prose, or as
  // an empty string when a tool takes no arguments.
  const rawArgs = call.rawArguments.trim();
  const parsedArgs = rawArgs === '' ? {} : parseJsonLoose(rawArgs);

  if (parsedArgs === null) {
    return record(
      {
        tool: tool.name,
        status: 'failed',
        summary: `Could not run ${humanise(tool.name)} — the arguments were malformed`,
        error: `Unparseable arguments: ${rawArgs.slice(0, 200)}`,
      },
      call,
      context,
    );
  }

  const validation = tool.parameters.safeParse(parsedArgs);
  if (!validation.success) {
    return record(
      {
        tool: tool.name,
        status: 'failed',
        summary: `Could not run ${humanise(tool.name)} — the arguments did not fit`,
        error: validation.error.issues
          .map((issue) => `${issue.path.join('.') || '(root)'}: ${issue.message}`)
          .join('; '),
      },
      call,
      context,
    );
  }

  try {
    const outcome = await tool.execute(validation.data, context);
    return record(
      {
        tool: tool.name,
        status: outcome.status,
        summary: outcome.summary,
        created: outcome.created,
        error: outcome.error,
      },
      call,
      context,
      validation.data as Record<string, unknown>,
    );
  } catch (error) {
    return record(
      {
        tool: tool.name,
        status: 'failed',
        summary: `${humanise(tool.name)} failed`,
        error: error instanceof Error ? error.message : String(error),
      },
      call,
      context,
      validation.data as Record<string, unknown>,
    );
  }
}

/** Persist the outcome, then hand it back for the response. */
async function record(
  action: ExecutedAction,
  _call: ResolvedToolCall,
  context: ToolContext,
  args?: Record<string, unknown>,
): Promise<ExecutedAction> {
  try {
    await getDb()
      .insert(agentActions)
      .values({
        runId: context.runId,
        noteId: context.noteId,
        dealId: context.dealId,
        tool: action.tool,
        args: args ?? null,
        status: action.status,
        source: context.source,
        summary: action.summary,
        error: action.error ?? null,
        resolvedAt: action.status === 'applied' ? context.now : null,
      });
  } catch (error) {
    // Losing the audit row must not lose the action itself — the write already
    // happened. Surface it on the action so it is visible rather than silent.
    return {
      ...action,
      error: [action.error, `audit write failed: ${describe(error)}`].filter(Boolean).join(' | '),
    };
  }

  return action;
}

/** Persist the model traces gathered during a run. */
export async function persistTraces(
  runId: string,
  traces: readonly ModelTrace[],
): Promise<void> {
  if (traces.length === 0) return;

  await getDb()
    .insert(modelTraces)
    .values(
      traces.map((trace) => ({
        runId,
        task: trace.task,
        tier: trace.tier,
        model: trace.model,
        promptTokens: trace.promptTokens,
        completionTokens: trace.completionTokens,
        latencyMs: trace.latencyMs,
        failed: trace.failed ?? false,
        error: trace.error ?? null,
      })),
    );
}

/** "set_reminder" becomes "set reminder", for user-facing copy. */
export function humanise(toolName: string): string {
  return toolName.replace(/_/g, ' ');
}

function describe(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
