import { parseCoachRecommendation } from './schemas';

describe('parseCoachRecommendation', () => {
  it('parses a valid advice-only recommendation (no proposed command)', () => {
    const raw = JSON.stringify({
      summary: 'Keep it up',
      rationale: 'Adherence has been strong for two weeks.',
      proposedCommand: null,
    });
    expect(parseCoachRecommendation(raw)).toEqual({
      summary: 'Keep it up',
      rationale: 'Adherence has been strong for two weeks.',
      proposedCommand: null,
    });
  });

  it('parses a valid nutritionTargetChange proposal', () => {
    const raw = JSON.stringify({
      summary: 'Small deficit adjustment',
      rationale: 'Weight loss has stalled for 3 weeks.',
      proposedCommand: {
        type: 'nutritionTargetChange',
        dailyCalories: 2100,
        proteinG: 160,
        carbsG: 200,
        fatG: 70,
      },
    });
    const result = parseCoachRecommendation(raw);
    expect(result.proposedCommand).toEqual({
      type: 'nutritionTargetChange',
      dailyCalories: 2100,
      proteinG: 160,
      carbsG: 200,
      fatG: 70,
    });
  });

  it('tolerates surrounding prose or a markdown code fence', () => {
    const raw = `Here you go:\n\`\`\`json\n${JSON.stringify({
      summary: 'ok',
      rationale: 'ok',
      proposedCommand: null,
    })}\n\`\`\``;
    expect(parseCoachRecommendation(raw).summary).toBe('ok');
  });

  it('throws if the response has no parseable JSON object', () => {
    expect(() => parseCoachRecommendation('I cannot help with that.')).toThrow();
  });

  it('throws if summary/rationale are missing', () => {
    const raw = JSON.stringify({ proposedCommand: null });
    expect(() => parseCoachRecommendation(raw)).toThrow();
  });

  it('throws if proposedCommand has an unknown type', () => {
    const raw = JSON.stringify({
      summary: 'ok',
      rationale: 'ok',
      proposedCommand: { type: 'deleteAllData' },
    });
    expect(() => parseCoachRecommendation(raw)).toThrow();
  });

  it('throws if a nutritionTargetChange is missing required numeric fields', () => {
    const raw = JSON.stringify({
      summary: 'ok',
      rationale: 'ok',
      proposedCommand: { type: 'nutritionTargetChange', dailyCalories: 'a lot' },
    });
    expect(() => parseCoachRecommendation(raw)).toThrow();
  });

  it('never coerces a malformed proposedCommand into a usable shape', () => {
    const raw = JSON.stringify({
      summary: 'ok',
      rationale: 'ok',
      proposedCommand: { type: 'goalChange', name: '' },
    });
    expect(() => parseCoachRecommendation(raw)).toThrow();
  });
});
