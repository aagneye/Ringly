import { describe, it, expect } from 'vitest';
import { whisperManifest } from '@/lib/whisper-manifest';

describe('whisperManifest', () => {
  const { models } = whisperManifest();

  it('returns at least one model', () => {
    expect(models.length).toBeGreaterThan(0);
  });

  it('has unique ids', () => {
    const ids = models.map((m) => m.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it('every url is an https Hugging Face link', () => {
    for (const model of models) {
      expect(model.url).toMatch(/^https:\/\/huggingface\.co\//);
    }
  });

  it('every sha256 is 64 hex chars (real, not invented)', () => {
    for (const model of models) {
      expect(model.sha256).toMatch(/^[0-9a-f]{64}$/);
    }
  });

  it('every size is larger than 10 MB', () => {
    for (const model of models) {
      expect(model.sizeBytes).toBeGreaterThan(10 * 1024 * 1024);
    }
  });

  it('exposes the two expected English models', () => {
    expect(models.map((m) => m.id).sort()).toEqual(['base.en', 'tiny.en']);
  });
});
