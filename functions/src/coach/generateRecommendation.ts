import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { AiProvider, defaultAiProvider } from '../ai/aiProvider';
import { parseCoachRecommendation } from '../ai/schemas';
import { buildCoachContext, CoachContext } from './buildCoachContext';
import { CoachFirestore, newDocId } from './firestorePort';
import { createAdminCoachFirestore } from './adminFirestore';
import { validateCommand } from './validateCommand';

function buildPrompt(context: CoachContext): string {
  return (
    'You are a fitness coach assistant. Given this JSON summary of a user\'s ' +
    'current goals, nutrition targets, adherence, readiness, and habits, ' +
    'respond with ONLY a JSON object with keys "summary" (a short string), ' +
    '"rationale" (a string explaining your reasoning), and "proposedCommand" ' +
    '(either null for advice-only, or an object with a "type" field of ' +
    '"nutritionTargetChange", "goalChange", "habitChange", or "workoutChange" ' +
    'and the relevant fields for that type). Do not include any other text.\n\n' +
    `User summary: ${JSON.stringify(context)}`
  );
}

export interface GenerateRecommendationResult {
  id: string;
}

/**
 * Builds a deterministic `CoachContext`, asks the AI provider for a
 * recommendation, validates its output against the runtime schema (invalid
 * output is rejected here and never written), runs it through the
 * deterministic command validator for an informational preliminary result,
 * and writes `coachRecommendations/{id}`.
 *
 * This function never mutates protected user data itself — writing the
 * recommendation record is the only write it performs. The preliminary
 * validation stored here (`preliminaryValidation`) is informational only:
 * `handleCommand` re-validates from scratch against freshly-read context
 * before ever applying a mutation, and must not trust this stored value.
 */
export async function generateRecommendationHandler(
  uid: string,
  db: CoachFirestore,
  aiProvider: AiProvider,
): Promise<GenerateRecommendationResult> {
  const context = await buildCoachContext(db, uid);
  const rawResponse = await aiProvider.generateCoachRecommendation(buildPrompt(context));
  const recommendation = parseCoachRecommendation(rawResponse);

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

export const generateRecommendation = onCall(
  { secrets: ['GROQ_API_KEY', 'NVIDIA_NIM_API_KEY'] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }
    try {
      return await generateRecommendationHandler(uid, createAdminCoachFirestore(), defaultAiProvider);
    } catch (error) {
      console.error('generateRecommendation failed', error);
      throw new HttpsError('internal', 'Could not generate a coach recommendation.');
    }
  },
);
