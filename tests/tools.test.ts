import { describe, it, expect } from 'vitest';
import {
  allTools,
  findTool,
  toolNames,
  wireTools,
  irreversibleToolNames,
} from '@/lib/agent/tools';

describe('tool registry', () => {
  it('registers every expected tool', () => {
    expect(toolNames()).toEqual([
      'update_deal',
      'set_reminder',
      'schedule_event',
      'draft_email',
      'lookup_company',
    ]);
  });

  it('finds a tool by name', () => {
    expect(findTool('set_reminder')?.name).toBe('set_reminder');
  });

  it('returns undefined for an unknown tool name', () => {
    expect(findTool('delete_everything')).toBeUndefined();
  });

  it('marks only email drafting as irreversible', () => {
    expect(irreversibleToolNames()).toEqual(['draft_email']);
  });

  it('gives every tool a non-trivial description', () => {
    for (const tool of allTools()) {
      expect(tool.description.length).toBeGreaterThan(40);
    }
  });

  it('gives every tool an object json schema with additionalProperties false', () => {
    for (const tool of allTools()) {
      expect(tool.jsonSchema.type).toBe('object');
      expect(tool.jsonSchema.additionalProperties).toBe(false);
    }
  });

  it('keeps zod and json schema property names in sync', () => {
    for (const tool of allTools()) {
      const jsonProps = Object.keys(
        (tool.jsonSchema.properties ?? {}) as Record<string, unknown>,
      ).sort();
      // Every json schema property must be accepted by the zod schema.
      for (const prop of jsonProps) {
        const probe = tool.parameters.safeParse({ [prop]: undefined });
        // A parse failure is fine (other fields may be required), but an
        // "unrecognised key" error would mean the schemas have drifted apart.
        if (!probe.success) {
          const unrecognised = probe.error.issues.some(
            (issue) => issue.code === 'unrecognized_keys',
          );
          expect(unrecognised).toBe(false);
        }
      }
    }
  });
});

describe('wireTools', () => {
  it('projects all tools into the OpenAI function shape', () => {
    const wire = wireTools();
    expect(wire).toHaveLength(5);
    for (const entry of wire) {
      expect(entry.type).toBe('function');
      expect(typeof entry.function.name).toBe('string');
      expect(typeof entry.function.description).toBe('string');
      expect(entry.function.parameters).toBeTypeOf('object');
    }
  });

  it('narrows to a requested subset', () => {
    const wire = wireTools(['draft_email', 'set_reminder']);
    expect(wire.map((entry) => entry.function.name).sort()).toEqual([
      'draft_email',
      'set_reminder',
    ]);
  });

  it('returns an empty list when the subset matches nothing', () => {
    expect(wireTools(['nope'])).toEqual([]);
  });
});

describe('tool argument validation', () => {
  it('rejects a reminder with no due date', () => {
    const tool = findTool('set_reminder')!;
    expect(tool.parameters.safeParse({ message: 'Chase the quote' }).success).toBe(false);
  });

  it('accepts a complete reminder', () => {
    const tool = findTool('set_reminder')!;
    expect(
      tool.parameters.safeParse({ message: 'Chase the quote', due: 'Friday' }).success,
    ).toBe(true);
  });

  it('rejects an out-of-range deal stage', () => {
    const tool = findTool('update_deal')!;
    expect(tool.parameters.safeParse({ stage: 'nearly_won' }).success).toBe(false);
  });

  it('accepts a deal update with every field omitted', () => {
    const tool = findTool('update_deal')!;
    expect(tool.parameters.safeParse({}).success).toBe(true);
  });

  it('rejects an event with an absurd duration', () => {
    const tool = findTool('schedule_event')!;
    expect(
      tool.parameters.safeParse({ title: 'Call', start: 'Friday', duration_minutes: 10_000 })
        .success,
    ).toBe(false);
  });

  it('rejects a company lookup with a one-character name', () => {
    const tool = findTool('lookup_company')!;
    expect(tool.parameters.safeParse({ company: 'X' }).success).toBe(false);
  });
});
