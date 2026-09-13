import { CoachFirestore } from './firestorePort';

/**
 * Bumped whenever the fields or semantics of `CoachContext` change, so a
 * recommendation record stays traceable to the context shape that produced
 * it (same convention as `BodyCompositionCalculator.calculationVersion` /
 * `readinessCalculationVersion`).
 */
export const coachContextSchemaVersion = 1;

export type ReadinessLevel = 'green' | 'yellow' | 'red';

/**
 * Compact projection of a `mealTemplates/{id}` document — just enough for
 * the coach to reference a template by id and for `mealPlanCost.ts` to
 * compute totals. Per-serving cost/nutrition is precomputed and stored on
 * the template itself (by the deterministic client-side calculator when the
 * template is created/priced), never derived from raw price snapshots here.
 */
export interface MealTemplateSummary {
  id: string;
  name: string;
  costPerServing: number | null;
  caloriesPerServing: number | null;
  proteinGPerServing: number | null;
}

export interface BudgetSummary {
  currency: string;
  dailyLimit: number | null;
  weeklyLimit: number | null;
  monthlyLimit: number | null;
}

/**
 * A deterministic, compact, versioned summary of a user's existing data —
 * never a raw Firestore dump. This is both a context-window budget and a
 * privacy boundary: only the fields the coach actually reasons about are
 * included, and every field here traces back to a specific query below.
 */
export interface CoachContext {
  contextSchemaVersion: number;
  generatedAt: string;
  goals: {
    activePrimary: {
      id: string;
      name: string;
      targetValue: number | null;
      unit: string | null;
    } | null;
    activeSecondaryCount: number;
  };
  nutrition: {
    dailyCalorieTarget: number | null;
    proteinTargetG: number | null;
    carbsTargetG: number | null;
    fatTargetG: number | null;
  };
  adherence: {
    latestWeeklyOverallScore: number | null;
  };
  readiness: {
    latestLevel: ReadinessLevel | null;
    latestSafetyOverrideTriggered: boolean;
  };
  habits: {
    activeCount: number;
  };
  mealPlanning: {
    budget: BudgetSummary | null;
    /**
     * Capped to a reasonable count so the context stays a compact summary
     * (same rationale as the rest of `CoachContext`) rather than a raw
     * Firestore dump — the meal-planning UI is the place to browse the full
     * template library, not the coach prompt.
     */
    templates: MealTemplateSummary[];
  };
}

function isReadinessLevel(value: unknown): value is ReadinessLevel {
  return value === 'green' || value === 'yellow' || value === 'red';
}

/** Picks the lexicographically-greatest doc id — `yyyy-MM-dd`/weekId ids sort as dates. */
function latestById<T extends { id: string }>(docs: T[]): T | null {
  if (docs.length === 0) return null;
  return docs.reduce((latest, doc) => (doc.id > latest.id ? doc : latest));
}

export async function buildCoachContext(db: CoachFirestore, uid: string): Promise<CoachContext> {
  const base = `users/${uid}`;

  const [goalDocs, nutritionGoalsDoc, weeklySummaries, readinessDocs, habitDocs, budgetDoc, mealTemplateDocs] =
    await Promise.all([
      db.getCollection(`${base}/goals`),
      db.getDoc(`${base}/nutritionGoals/goals`),
      db.getCollection(`${base}/adherenceWeekly`),
      db.getCollection(`${base}/readiness`),
      db.getCollection(`${base}/habits`),
      db.getDoc(`${base}/budgetSettings/current`),
      db.getCollection(`${base}/mealTemplates`),
    ]);

  const MAX_TEMPLATES_IN_CONTEXT = 50;
  const templates: MealTemplateSummary[] = mealTemplateDocs.slice(0, MAX_TEMPLATES_IN_CONTEXT).map((doc) => ({
    id: doc.id,
    name: typeof doc.data.name === 'string' ? doc.data.name : '',
    costPerServing: typeof doc.data.costPerServing === 'number' ? doc.data.costPerServing : null,
    caloriesPerServing: typeof doc.data.caloriesPerServing === 'number' ? doc.data.caloriesPerServing : null,
    proteinGPerServing: typeof doc.data.proteinGPerServing === 'number' ? doc.data.proteinGPerServing : null,
  }));

  const budget: BudgetSummary | null = budgetDoc
    ? {
        currency: typeof budgetDoc.currency === 'string' ? budgetDoc.currency : 'USD',
        dailyLimit: typeof budgetDoc.dailyLimit === 'number' ? budgetDoc.dailyLimit : null,
        weeklyLimit: typeof budgetDoc.weeklyLimit === 'number' ? budgetDoc.weeklyLimit : null,
        monthlyLimit: typeof budgetDoc.monthlyLimit === 'number' ? budgetDoc.monthlyLimit : null,
      }
    : null;

  const activePrimaryDoc = goalDocs.find(
    (goal) => goal.data.category === 'primary' && goal.data.status === 'active',
  );
  const activeSecondaryCount = goalDocs.filter(
    (goal) => goal.data.category !== 'primary' && goal.data.status === 'active',
  ).length;

  const latestWeekly = latestById(weeklySummaries);
  const latestReadiness = latestById(readinessDocs);
  const latestReadinessResult = latestReadiness?.data.result as Record<string, unknown> | undefined;

  return {
    contextSchemaVersion: coachContextSchemaVersion,
    generatedAt: new Date().toISOString(),
    goals: {
      activePrimary: activePrimaryDoc
        ? {
            id: activePrimaryDoc.id,
            name: typeof activePrimaryDoc.data.name === 'string' ? activePrimaryDoc.data.name : '',
            targetValue:
              typeof activePrimaryDoc.data.targetValue === 'number' ? activePrimaryDoc.data.targetValue : null,
            unit: typeof activePrimaryDoc.data.unit === 'string' ? activePrimaryDoc.data.unit : null,
          }
        : null,
      activeSecondaryCount,
    },
    nutrition: {
      dailyCalorieTarget:
        typeof nutritionGoalsDoc?.dailyCalories === 'number' ? nutritionGoalsDoc.dailyCalories : null,
      proteinTargetG: typeof nutritionGoalsDoc?.proteinG === 'number' ? nutritionGoalsDoc.proteinG : null,
      carbsTargetG: typeof nutritionGoalsDoc?.carbsG === 'number' ? nutritionGoalsDoc.carbsG : null,
      fatTargetG: typeof nutritionGoalsDoc?.fatG === 'number' ? nutritionGoalsDoc.fatG : null,
    },
    adherence: {
      latestWeeklyOverallScore:
        typeof latestWeekly?.data.overallScore === 'number' ? latestWeekly.data.overallScore : null,
    },
    readiness: {
      latestLevel: isReadinessLevel(latestReadinessResult?.level) ? (latestReadinessResult!.level as ReadinessLevel) : null,
      latestSafetyOverrideTriggered: latestReadinessResult?.safetyOverrideTriggered === true,
    },
    habits: {
      activeCount: habitDocs.filter((habit) => habit.data.archived !== true).length,
    },
    mealPlanning: {
      budget,
      templates,
    },
  };
}
