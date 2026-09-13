import { parseCoachRecommendation, parseMealPlanRecommendation } from './schemas';

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

  it('parses a valid mealPlanChange proposal', () => {
    const raw = JSON.stringify({
      summary: 'Budget-friendly daily plan',
      rationale: 'Uses your two cheapest templates.',
      proposedCommand: {
        type: 'mealPlanChange',
        planId: null,
        name: 'Cheap daily plan',
        periodType: 'daily',
        items: [{ templateId: 't1', servings: 2 }],
      },
    });
    const result = parseCoachRecommendation(raw);
    expect(result.proposedCommand).toEqual({
      type: 'mealPlanChange',
      planId: null,
      name: 'Cheap daily plan',
      periodType: 'daily',
      items: [{ templateId: 't1', servings: 2 }],
    });
  });

  it('throws if a mealPlanChange has an empty items array', () => {
    const raw = JSON.stringify({
      summary: 'ok',
      rationale: 'ok',
      proposedCommand: { type: 'mealPlanChange', planId: null, name: 'x', periodType: 'daily', items: [] },
    });
    expect(() => parseCoachRecommendation(raw)).toThrow();
  });

  it('throws if a mealPlanChange item has a non-positive servings count', () => {
    const raw = JSON.stringify({
      summary: 'ok',
      rationale: 'ok',
      proposedCommand: {
        type: 'mealPlanChange',
        planId: null,
        name: 'x',
        periodType: 'daily',
        items: [{ templateId: 't1', servings: 0 }],
      },
    });
    expect(() => parseCoachRecommendation(raw)).toThrow();
  });

  it('throws if a mealPlanChange has an invalid periodType', () => {
    const raw = JSON.stringify({
      summary: 'ok',
      rationale: 'ok',
      proposedCommand: {
        type: 'mealPlanChange',
        planId: null,
        name: 'x',
        periodType: 'monthly',
        items: [{ templateId: 't1', servings: 1 }],
      },
    });
    expect(() => parseCoachRecommendation(raw)).toThrow();
  });
});

describe('parseMealPlanRecommendation', () => {
  it('accepts a valid mealPlanChange proposal', () => {
    const raw = JSON.stringify({
      summary: 'ok',
      rationale: 'ok',
      proposedCommand: {
        type: 'mealPlanChange',
        planId: null,
        name: 'x',
        periodType: 'daily',
        items: [{ templateId: 't1', servings: 1 }],
      },
    });
    expect(parseMealPlanRecommendation(raw).proposedCommand).toMatchObject({ type: 'mealPlanChange' });
  });

  it('accepts a null proposedCommand', () => {
    const raw = JSON.stringify({ summary: 'ok', rationale: 'ok', proposedCommand: null });
    expect(parseMealPlanRecommendation(raw).proposedCommand).toBeNull();
  });

  it('rejects a well-formed proposal of a different command type — this call site only ever asked for a meal plan', () => {
    const raw = JSON.stringify({
      summary: 'ok',
      rationale: 'ok',
      proposedCommand: { type: 'habitChange', habitId: null, name: 'x', cadence: 'daily', timesPerWeek: null, archived: false },
    });
    expect(() => parseMealPlanRecommendation(raw)).toThrow();
  });
});
