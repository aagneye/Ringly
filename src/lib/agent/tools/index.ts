import { updateDealTool } from './update-deal';
import { setReminderTool } from './set-reminder';
import { scheduleEventTool } from './schedule-event';
import { draftEmailTool } from './draft-email';
import { lookupCompanyTool } from './lookup-company';
import { toWireTool, type ToolDefinition, type WireTool } from './types';

/**
 * The toolbox the agent chooses from.
 *
 * Order matters a little: models weight earlier tools slightly more, so the
 * ones that should fire on almost every memo come first and the situational ones
 * come last.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const ALL_TOOLS: ToolDefinition<any>[] = [
  updateDealTool,
  setReminderTool,
  scheduleEventTool,
  draftEmailTool,
  lookupCompanyTool,
];

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const BY_NAME = new Map<string, ToolDefinition<any>>(ALL_TOOLS.map((tool) => [tool.name, tool]));

/** Every registered tool. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function allTools(): readonly ToolDefinition<any>[] {
  return ALL_TOOLS;
}

/** Look up a tool by the name the model used. */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function findTool(name: string): ToolDefinition<any> | undefined {
  return BY_NAME.get(name);
}

/** Tool names, for prompt construction and tests. */
export function toolNames(): readonly string[] {
  return ALL_TOOLS.map((tool) => tool.name);
}

/** Wire definitions for the model, optionally narrowed to a subset. */
export function wireTools(only?: readonly string[]): WireTool[] {
  const selected = only ? ALL_TOOLS.filter((tool) => only.includes(tool.name)) : ALL_TOOLS;
  return selected.map((tool) => toWireTool(tool));
}

/** Names of tools whose effects cannot be undone, so they need approval. */
export function irreversibleToolNames(): readonly string[] {
  return ALL_TOOLS.filter((tool) => !tool.reversible).map((tool) => tool.name);
}

export { updateDealTool, setReminderTool, scheduleEventTool, draftEmailTool, lookupCompanyTool };
export type { ToolDefinition, WireTool };
