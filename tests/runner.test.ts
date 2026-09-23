import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { ToolContext } from '@/lib/agent/tools/types';

/**
 * The database is mocked rather than stood up, because what needs proving here
 * is the runner's control flow: bad input becomes a recorded failure, and one
 * failing tool does not take its siblings down with it.
 */
const insertedRows: Record<string, unknown>[] = [];

vi.mock('@/lib/db', () => ({
  getDb: () => ({
    insert: () => ({
      values: (rows: Record<string, unknown> | Record<string, unknown>[]) => {
        const list = Array.isArray(rows) ? rows : [rows];
        insertedRows.push(...list);
        return {
          returning: async () => list.map((row, index) => ({ id: `row-${index}`, ...row })),
          then: (resolve: (value: unknown) => unknown) => resolve(undefined),
        };
      },
    }),
  }),
}));

const executeSpy = vi.fn();
const failingSpy = vi.fn();

vi.mock('@/lib/agent/tools', async () => {
  const { z } = await import('zod');
  return {
    findTool: (name: string) => {
      if (name === 'good_tool') {
        return {
          name: 'good_tool',
          description: 'A tool that works.',
          parameters: z.object({ value: z.string().min(1) }),
          jsonSchema: { type: 'object', properties: {}, additionalProperties: false },
          reversible: true,
          execute: executeSpy,
        };
      }
      if (name === 'throwing_tool') {
        return {
          name: 'throwing_tool',
          description: 'A tool that explodes.',
          parameters: z.object({}),
          jsonSchema: { type: 'object', properties: {}, additionalProperties: false },
          reversible: true,
          execute: failingSpy,
        };
      }
      return undefined;
    },
  };
});

const { executeToolCalls, humanise } = await import('@/lib/agent/runner');

function context(): ToolContext {
  return {
    runId: 'run-1',
    now: new Date('2026-09-23T12:00:00Z'),
    noteId: 'note-1',
    dealId: 'deal-1',
    contactId: 'contact-1',
    source: 'memo',
    userName: 'Alex',
    timezone: 'Asia/Kolkata',
  };
}

beforeEach(() => {
  insertedRows.length = 0;
  executeSpy.mockReset();
  failingSpy.mockReset();
  executeSpy.mockResolvedValue({ status: 'applied', summary: 'Did the thing' });
  failingSpy.mockRejectedValue(new Error('database exploded'));
});

describe('executeToolCalls', () => {
  it('returns an empty report for no calls', async () => {
    const report = await executeToolCalls([], context());
    expect(report.actions).toEqual([]);
    expect(report.applied).toEqual([]);
  });

  it('executes a valid call and reports it applied', async () => {
    const report = await executeToolCalls(
      [{ id: '1', name: 'good_tool', rawArguments: '{"value":"hello"}' }],
      context(),
    );
    expect(executeSpy).toHaveBeenCalledOnce();
    expect(report.applied).toHaveLength(1);
    expect(report.applied[0]!.summary).toBe('Did the thing');
  });

  it('records an unknown tool as failed without throwing', async () => {
    const report = await executeToolCalls(
      [{ id: '1', name: 'nonexistent', rawArguments: '{}' }],
      context(),
    );
    expect(report.failed).toHaveLength(1);
    expect(report.failed[0]!.error).toContain('No tool named nonexistent');
  });

  it('records malformed arguments as failed', async () => {
    const report = await executeToolCalls(
      [{ id: '1', name: 'good_tool', rawArguments: 'not json at all' }],
      context(),
    );
    expect(executeSpy).not.toHaveBeenCalled();
    expect(report.failed[0]!.summary).toContain('malformed');
  });

  it('records arguments that fail validation as failed', async () => {
    const report = await executeToolCalls(
      [{ id: '1', name: 'good_tool', rawArguments: '{"value":""}' }],
      context(),
    );
    expect(executeSpy).not.toHaveBeenCalled();
    expect(report.failed[0]!.summary).toContain('did not fit');
    expect(report.failed[0]!.error).toContain('value');
  });

  it('recovers arguments wrapped in a markdown fence', async () => {
    const report = await executeToolCalls(
      [{ id: '1', name: 'good_tool', rawArguments: '```json\n{"value":"hi"}\n```' }],
      context(),
    );
    expect(report.applied).toHaveLength(1);
  });

  it('treats empty arguments as an empty object', async () => {
    const report = await executeToolCalls(
      [{ id: '1', name: 'throwing_tool', rawArguments: '' }],
      context(),
    );
    // Validation passes with {}, so the tool runs and its own error is recorded.
    expect(failingSpy).toHaveBeenCalledOnce();
    expect(report.failed[0]!.error).toContain('database exploded');
  });

  it('catches a throwing tool and records it as failed', async () => {
    const report = await executeToolCalls(
      [{ id: '1', name: 'throwing_tool', rawArguments: '{}' }],
      context(),
    );
    expect(report.failed).toHaveLength(1);
    expect(report.failed[0]!.status).toBe('failed');
  });

  it('keeps executing siblings after one tool fails', async () => {
    const report = await executeToolCalls(
      [
        { id: '1', name: 'throwing_tool', rawArguments: '{}' },
        { id: '2', name: 'good_tool', rawArguments: '{"value":"still ran"}' },
        { id: '3', name: 'nonexistent', rawArguments: '{}' },
      ],
      context(),
    );
    expect(report.actions).toHaveLength(3);
    expect(report.applied).toHaveLength(1);
    expect(report.failed).toHaveLength(2);
  });

  it('separates actions awaiting approval from applied ones', async () => {
    executeSpy.mockResolvedValue({
      status: 'awaiting_approval',
      summary: 'Drafted an email',
    });
    const report = await executeToolCalls(
      [{ id: '1', name: 'good_tool', rawArguments: '{"value":"x"}' }],
      context(),
    );
    expect(report.awaitingApproval).toHaveLength(1);
    expect(report.applied).toHaveLength(0);
  });

  it('writes an audit row for every call, including failures', async () => {
    await executeToolCalls(
      [
        { id: '1', name: 'good_tool', rawArguments: '{"value":"x"}' },
        { id: '2', name: 'nonexistent', rawArguments: '{}' },
      ],
      context(),
    );
    expect(insertedRows).toHaveLength(2);
    expect(insertedRows.map((row) => row.status).sort()).toEqual(['applied', 'failed']);
  });

  it('stamps the audit row with the run id and source', async () => {
    await executeToolCalls(
      [{ id: '1', name: 'good_tool', rawArguments: '{"value":"x"}' }],
      context(),
    );
    expect(insertedRows[0]!.runId).toBe('run-1');
    expect(insertedRows[0]!.source).toBe('memo');
  });

  it('passes validated arguments to the tool, not the raw string', async () => {
    await executeToolCalls(
      [{ id: '1', name: 'good_tool', rawArguments: '{"value":"parsed"}' }],
      context(),
    );
    expect(executeSpy.mock.calls[0]![0]).toEqual({ value: 'parsed' });
  });
});

describe('humanise', () => {
  it('replaces underscores with spaces', () => {
    expect(humanise('set_reminder')).toBe('set reminder');
  });

  it('leaves a single word alone', () => {
    expect(humanise('transcribe')).toBe('transcribe');
  });
});
