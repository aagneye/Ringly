import { describe, it, expect } from 'vitest';
import {
  buildPlannerPrompt,
  PLANNER_SYSTEM_PROMPT,
  type PlannerContext,
} from '@/lib/agent/prompts/planner';
import type { Extraction } from '@/lib/agent/prompts/extract';

const baseExtraction: Extraction = {
  contact_name: 'Priya',
  company: 'Northwind',
  stage_guess: 'proposal',
  next_action: 'send the pricing sheet',
  deadline: 'Friday',
  budget: 'around 12k',
  concerns: 'onboarding time',
  sentiment: 'positive',
  gist: 'Priya wants pricing before the board meeting.',
};

function context(overrides: Partial<PlannerContext> = {}): PlannerContext {
  return {
    extraction: baseExtraction,
    transcript: 'spoke to priya she wants pricing before friday',
    contactName: 'Priya Sharma',
    company: 'Northwind',
    dealTitle: 'Northwind pilot',
    currentStage: 'contacted',
    hasCompanyFacts: false,
    openReminders: [],
    daysSinceLastContact: 3,
    todayLabel: 'Wednesday 23 September 2026',
    ...overrides,
  };
}

describe('PLANNER_SYSTEM_PROMPT', () => {
  it('permits doing nothing, so the agent is not pushed into busywork', () => {
    expect(PLANNER_SYSTEM_PROMPT).toContain('Doing nothing is a valid plan');
  });

  it('distinguishes a reminder from a calendar event', () => {
    expect(PLANNER_SYSTEM_PROMPT).toContain('A reminder is for a task');
    expect(PLANNER_SYSTEM_PROMPT).toContain('calendar event is for a meeting');
  });

  it('tells the model to call tools in parallel', () => {
    expect(PLANNER_SYSTEM_PROMPT).toContain('all at once');
  });
});

describe('buildPlannerPrompt', () => {
  it('states today so relative dates can be reasoned about', () => {
    expect(buildPlannerPrompt(context())).toContain('Wednesday 23 September 2026');
  });

  it('names the contact, company, deal and stage', () => {
    const prompt = buildPlannerPrompt(context());
    expect(prompt).toContain('Priya Sharma');
    expect(prompt).toContain('Northwind');
    expect(prompt).toContain('Northwind pilot');
    expect(prompt).toContain('contacted stage');
  });

  it('includes the verbatim transcript', () => {
    expect(buildPlannerPrompt(context())).toContain('spoke to priya she wants pricing before friday');
  });

  it('flags a first conversation', () => {
    expect(buildPlannerPrompt(context({ daysSinceLastContact: null }))).toContain(
      'first recorded conversation',
    );
  });

  it('flags a re-engagement after a long gap', () => {
    expect(buildPlannerPrompt(context({ daysSinceLastContact: 30 }))).toContain('re-engagement');
  });

  it('says nothing about gaps for a recent conversation', () => {
    const prompt = buildPlannerPrompt(context({ daysSinceLastContact: 2 }));
    expect(prompt).not.toContain('re-engagement');
    expect(prompt).not.toContain('first recorded conversation');
  });

  it('lists open reminders so they are not duplicated', () => {
    const prompt = buildPlannerPrompt(
      context({ openReminders: ['Chase the signed order form'] }),
    );
    expect(prompt).toContain('do not duplicate');
    expect(prompt).toContain('Chase the signed order form');
  });

  it('omits the reminder section when none are open', () => {
    expect(buildPlannerPrompt(context())).not.toContain('do not duplicate');
  });

  it('caps the reminder list', () => {
    const many = Array.from({ length: 20 }, (_, i) => `Reminder ${i}`);
    const prompt = buildPlannerPrompt(context({ openReminders: many }));
    expect(prompt).not.toContain('Reminder 15');
  });

  it('suppresses company lookup when facts are cached', () => {
    expect(buildPlannerPrompt(context({ hasCompanyFacts: true }))).toContain(
      'lookup_company is unnecessary',
    );
  });

  it('renders every extracted field that has a value', () => {
    const prompt = buildPlannerPrompt(context());
    expect(prompt).toContain('send the pricing sheet');
    expect(prompt).toContain('around 12k');
    expect(prompt).toContain('onboarding time');
  });

  it('says so explicitly when extraction found nothing', () => {
    const empty: Extraction = {
      contact_name: null,
      company: null,
      stage_guess: null,
      next_action: null,
      deadline: null,
      budget: null,
      concerns: null,
      sentiment: null,
      gist: 'Quick hello, nothing discussed.',
    };
    expect(buildPlannerPrompt(context({ extraction: empty }))).toContain(
      'Nothing concrete was extracted',
    );
  });

  it('omits the company clause when no company is known', () => {
    const prompt = buildPlannerPrompt(context({ company: null }));
    expect(prompt).toContain('This memo is about Priya Sharma, on the deal');
  });
});
