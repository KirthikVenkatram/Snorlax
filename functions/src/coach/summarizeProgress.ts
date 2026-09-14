import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { AiProvider, defaultAiProvider } from '../ai/aiProvider';
import { buildCoachContext, CoachContext } from './buildCoachContext';
import { CoachFirestore } from './firestorePort';
import { createAdminCoachFirestore } from './adminFirestore';

function buildPrompt(context: CoachContext): string {
  return (
    'You are a supportive fitness coach. Given this JSON summary of a ' +
    "user's current goals, nutrition targets, adherence, readiness, and " +
    'habits, write a short (2-4 sentence) natural-language summary of their ' +
    'recent progress: call out nutrition adherence, training/habit ' +
    'consistency, goal progress, and readiness trend where the data ' +
    'supports it. Be encouraging and specific, but do not invent numbers ' +
    "that aren't present in the summary. Respond with plain text only, no " +
    'JSON, no markdown.\n\n' +
    `User summary: ${JSON.stringify(context)}`
  );
}

export interface SummarizeProgressResult {
  summary: string;
}

/**
 * Builds a deterministic `CoachContext` and asks the AI provider for a
 * short natural-language progress summary. Unlike `generateRecommendation`/
 * `generateMealPlanRecommendation`, this is read-only and advisory: it never
 * proposes a command, never touches protected data, and so has no need to
 * go through `validateCommand`/`handleCommand`'s approval flow or be
 * persisted to `coachRecommendations`. The summary text is simply returned
 * to the caller. See docs/superpowers/ISSUES.md, "Post-audit wiring", for
 * the reasoning behind this design.
 */
export async function summarizeProgressHandler(
  uid: string,
  db: CoachFirestore,
  aiProvider: AiProvider,
): Promise<SummarizeProgressResult> {
  const context = await buildCoachContext(db, uid);
  const summary = await aiProvider.summarizeProgress(buildPrompt(context));
  return { summary: summary.trim() };
}

export const summarizeProgress = onCall(
  { secrets: ['GROQ_API_KEY', 'NVIDIA_NIM_API_KEY'] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }
    try {
      return await summarizeProgressHandler(uid, createAdminCoachFirestore(), defaultAiProvider);
    } catch (error) {
      console.error('summarizeProgress failed', error);
      throw new HttpsError('internal', 'Could not summarize progress.');
    }
  },
);
