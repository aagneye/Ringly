/**
 * Recovering JSON from a model that ignored the response_format instruction.
 *
 * Token Factory supports strict `json_schema` output, but not on every model
 * and not on every retry path. A single wrapped response ("Sure! Here's the
 * JSON: ```json {...}```") would otherwise crash a live demo, so every
 * structured call funnels through this parser.
 *
 * Deliberately dependency-free and pure, which makes it cheap to test against
 * the malformed shapes models actually emit.
 */

/** Strip markdown fences, prose preambles and trailing commentary. */
export function extractJsonBlock(raw: string): string | null {
  if (!raw) return null;

  const trimmed = raw.trim();

  // Fast path: already valid JSON.
  if (isParseable(trimmed)) return trimmed;

  // Fenced block, with or without a language tag.
  const fenced = trimmed.match(/```(?:json|JSON)?\s*([\s\S]*?)```/);
  if (fenced?.[1] && isParseable(fenced[1].trim())) {
    return fenced[1].trim();
  }

  // Reasoning models sometimes emit a <think> block before the answer.
  const afterThink = trimmed.replace(/<think>[\s\S]*?<\/think>/g, '').trim();
  if (afterThink !== trimmed && isParseable(afterThink)) {
    return afterThink;
  }

  // Last resort: balance braces or brackets from the first opener onwards.
  const balanced = balancedSpan(afterThink || trimmed);
  if (balanced && isParseable(balanced)) return balanced;

  return null;
}

function isParseable(candidate: string): boolean {
  if (!candidate) return false;
  try {
    JSON.parse(candidate);
    return true;
  } catch {
    return false;
  }
}

/**
 * Scan forward from the first `{` or `[` and return the span that closes it,
 * ignoring braces that appear inside string literals.
 */
function balancedSpan(text: string): string | null {
  const openIndex = firstOpenerIndex(text);
  if (openIndex === -1) return null;

  const opener = text[openIndex];
  const closer = opener === '{' ? '}' : ']';

  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let i = openIndex; i < text.length; i += 1) {
    const char = text[i];

    if (escaped) {
      escaped = false;
      continue;
    }
    if (char === '\\') {
      escaped = true;
      continue;
    }
    if (char === '"') {
      inString = !inString;
      continue;
    }
    if (inString) continue;

    if (char === opener) depth += 1;
    else if (char === closer) {
      depth -= 1;
      if (depth === 0) return text.slice(openIndex, i + 1);
    }
  }

  return null;
}

function firstOpenerIndex(text: string): number {
  const brace = text.indexOf('{');
  const bracket = text.indexOf('[');
  if (brace === -1) return bracket;
  if (bracket === -1) return brace;
  return Math.min(brace, bracket);
}

/** Parse model output into an unknown value, or null if nothing usable exists. */
export function parseJsonLoose(raw: string): unknown | null {
  const block = extractJsonBlock(raw);
  if (block === null) return null;
  try {
    return JSON.parse(block);
  } catch {
    return null;
  }
}
