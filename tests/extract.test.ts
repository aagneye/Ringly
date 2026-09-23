import { describe, it, expect } from 'vitest';
import {
  cleanNullish,
  normaliseExtraction,
  buildExtractionPrompt,
  extractionSchema,
  EXTRACTION_WIRE_SCHEMA,
  type Extraction,
} from '@/lib/agent/prompts/extract';

function extraction(overrides: Partial<Extraction> = {}): Extraction {
  return {
    contact_name: 'Priya',
    company: 'Northwind',
    stage_guess: 'proposal',
    next_action: 'send the pricing sheet',
    deadline: 'Friday',
    budget: 'around 12k',
    concerns: 'worried about onboarding time',
    sentiment: 'positive',
    gist: 'Priya wants pricing before her board meeting.',
    ...overrides,
  };
}

describe('cleanNullish', () => {
  it('passes a real value through trimmed', () => {
    expect(cleanNullish('  Priya  ')).toBe('Priya');
  });

  it('keeps null as null', () => {
    expect(cleanNullish(null)).toBeNull();
  });

  it('treats an empty string as null', () => {
    expect(cleanNullish('   ')).toBeNull();
  });

  it.each(['null', 'None', 'N/A', 'na', 'unknown', 'Not mentioned', 'not specified', '-'])(
    'treats the placeholder %s as null',
    (placeholder) => {
      expect(cleanNullish(placeholder)).toBeNull();
    },
  );

  it('does not mistake a real value containing a placeholder word', () => {
    expect(cleanNullish('unknown budget authority')).toBe('unknown budget authority');
  });
});

describe('normaliseExtraction', () => {
  it('cleans placeholders across every text field', () => {
    const result = normaliseExtraction(
      extraction({
        company: 'N/A',
        next_action: 'none',
        deadline: '  ',
        budget: 'not mentioned',
        concerns: 'null',
      }),
    );
    expect(result.company).toBeNull();
    expect(result.next_action).toBeNull();
    expect(result.deadline).toBeNull();
    expect(result.budget).toBeNull();
    expect(result.concerns).toBeNull();
  });

  it('leaves genuine values untouched', () => {
    const input = extraction();
    expect(normaliseExtraction(input)).toEqual(input);
  });

  it('preserves the gist verbatim', () => {
    const result = normaliseExtraction(extraction({ gist: 'Short call, nothing decided.' }));
    expect(result.gist).toBe('Short call, nothing decided.');
  });

  it('preserves a null stage rather than defaulting it', () => {
    expect(normaliseExtraction(extraction({ stage_guess: null })).stage_guess).toBeNull();
  });
});

describe('extractionSchema', () => {
  it('accepts a fully populated extraction', () => {
    expect(extractionSchema.safeParse(extraction()).success).toBe(true);
  });

  it('accepts an extraction where everything optional is null', () => {
    const sparse = {
      contact_name: null,
      company: null,
      stage_guess: null,
      next_action: null,
      deadline: null,
      budget: null,
      concerns: null,
      sentiment: null,
      gist: 'Brief check-in call.',
    };
    expect(extractionSchema.safeParse(sparse).success).toBe(true);
  });

  it('rejects an invented pipeline stage', () => {
    expect(extractionSchema.safeParse(extraction({ stage_guess: 'closing' as never }).success)).toBeDefined();
    expect(extractionSchema.safeParse({ ...extraction(), stage_guess: 'closing' }).success).toBe(
      false,
    );
  });

  it('requires a gist', () => {
    const { gist: _gist, ...withoutGist } = extraction();
    expect(extractionSchema.safeParse(withoutGist).success).toBe(false);
  });
});

describe('buildExtractionPrompt', () => {
  it('includes the transcript', () => {
    expect(buildExtractionPrompt('spoke to priya today', [])).toContain('spoke to priya today');
  });

  it('omits the roster section when there are no known contacts', () => {
    expect(buildExtractionPrompt('hello', [])).not.toContain('already in the CRM');
  });

  it('lists known contacts to anchor the spelling', () => {
    const prompt = buildExtractionPrompt('spoke to priya', ['Priya Sharma', 'Ahmed Khan']);
    expect(prompt).toContain('Priya Sharma');
    expect(prompt).toContain('Ahmed Khan');
  });

  it('caps the roster so a large CRM cannot blow the context window', () => {
    const many = Array.from({ length: 200 }, (_, i) => `Contact ${i}`);
    const prompt = buildExtractionPrompt('hello', many);
    expect(prompt).not.toContain('Contact 50');
  });
});

describe('EXTRACTION_WIRE_SCHEMA', () => {
  it('requires every field so the model cannot omit keys', () => {
    const required = EXTRACTION_WIRE_SCHEMA.schema.required;
    const properties = Object.keys(EXTRACTION_WIRE_SCHEMA.schema.properties);
    expect([...required].sort()).toEqual(properties.sort());
  });

  it('forbids additional properties', () => {
    expect(EXTRACTION_WIRE_SCHEMA.schema.additionalProperties).toBe(false);
  });
});
