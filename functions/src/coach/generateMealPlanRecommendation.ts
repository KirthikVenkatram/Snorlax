import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { AiProvider, defaultAiProvider } from '../ai/aiProvider';
import { parseMealPlanRecommendation } from '../ai/schemas';
import { buildCoachContext, CoachContext } from './buildCoachContext';
import { CoachFirestore, newDocId } from './firestorePort';
import { createAdminCoachFirestore } from './adminFirestore';
import { validateCommand } from './validateCommand';

/**
 * Closes the Phase 7 `generateMealPlanProposal` seam: this is the first
 * (and, as of Phase 8, only) caller of `AiProvider.generateMealPlanProposal`,
 * built the same way `generateRecommendation.ts` calls
 * `generateCoachRecommendation` — build a deterministic context, ask the
 * provider, schema-validate, run the (informational) preliminary validator,
 * write a `coachRecommendations` doc. It is a separate callable/prompt from
 * `generateRecommendation` because it targets a distinct `AiProvider`
 * operation and a budget/template-focused prompt, but the resulting
 * `coachRecommendations` document and downstream `handleCommand` flow are
 * identical to every other proposal type — no separate accept/reject path
 * exists for meal plans.
 */
function buildMealPlanPrompt(context: CoachContext): string {
  return (
    'You are a budget-aware meal planning assistant. Given this JSON summary ' +
    "of a user's budget and their existing reusable meal templates, respond " +
    'with ONLY a JSON object with keys "summary" (a short string), ' +
    '"rationale" (a string explaining your reasoning), and "proposedCommand" ' +
    '(either null if no plan can be proposed, e.g. no templates exist yet, or ' +
    'an object with "type": "mealPlanChange", "planId": null, "name": a short ' +
    'plan name, "periodType": "daily" or "weekly", and "items": an array of ' +
    '{"templateId", "servings"} objects referencing ONLY the template ids ' +
    'listed below — never invent a templateId, and never include cost, ' +
    'calorie, or protein numbers yourself; those are computed separately from ' +
    'the templates you reference). Do not include any other text.\n\n' +
    `User summary: ${JSON.stringify({ budget: context.mealPlanning.budget, templates: context.mealPlanning.templates })}`
  );
}

export interface GenerateMealPlanRecommendationResult {
  id: string;
}

export async function generateMealPlanRecommendationHandler(
  uid: string,
  db: CoachFirestore,
  aiProvider: AiProvider,
): Promise<GenerateMealPlanRecommendationResult> {
  const context = await buildCoachContext(db, uid);
  const rawResponse = await aiProvider.generateMealPlanProposal(buildMealPlanPrompt(context));
  const recommendation = parseMealPlanRecommendation(rawResponse);

  const preliminaryValidation = recommendation.proposedCommand
    ? validateCommand(recommendation.proposedCommand, context)
    : null;

  const id = newDocId();
  await db.setDoc(`users/${uid}/coachRecommendations/${id}`, {
    contextSchemaVersion: context.contextSchemaVersion,
    context,
    summary: recommendation.summary,
    rationale: recommendation.rationale,
    proposedCommand: recommendation.proposedCommand,
    preliminaryValidation,
    status: 'pending',
    createdAt: new Date().toISOString(),
  });

  return { id };
}

export const generateMealPlanRecommendation = onCall(
  { secrets: ['GROQ_API_KEY', 'NVIDIA_NIM_API_KEY'] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }
    try {
      return await generateMealPlanRecommendationHandler(uid, createAdminCoachFirestore(), defaultAiProvider);
    } catch (error) {
      console.error('generateMealPlanRecommendation failed', error);
      throw new HttpsError('internal', 'Could not generate a meal plan recommendation.');
    }
  },
);
