import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { ProposedCommand } from '../ai/schemas';
import { buildCoachContext, CoachContext } from './buildCoachContext';
import { CoachFirestore, newDocId } from './firestorePort';
import { createAdminCoachFirestore } from './adminFirestore';
import { validateCommand } from './validateCommand';
import { computeMealPlanCost } from './mealPlanCost';

export type CoachDecision = 'approve' | 'reject';

export type CoachEventOutcome = 'applied' | 'rejectedByUser' | 'rejectedByValidation' | 'failed';

export interface HandleCommandResult {
  outcome: CoachEventOutcome;
  reason: string;
}

interface RecommendationDoc {
  proposedCommand: ProposedCommand | null;
  status?: string;
}

/**
 * Applies an approved, freshly-revalidated command by writing directly to
 * the protected collection it targets. This is the *only* function in the
 * codebase that writes to `goals`, `nutritionGoals`, or `habits` on an
 * AI-originated proposal's behalf — every other path (schema validation,
 * `validateCommand`) only decides whether this function gets to run.
 *
 * `workoutChange` has no structured write target yet (workouts has no
 * coach-proposable schema) — it is advisory-only and intentionally a no-op
 * here. See docs/superpowers/ISSUES.md, "Phase 7".
 *
 * `mealPlanChange` is the one command type whose write requires more than
 * the command's own fields: the actual `mealPlans` document is a
 * deterministically-computed cost/nutrition aggregate (via
 * `computeMealPlanCost`), never AI-supplied numbers, so `context` (freshly
 * rebuilt by the caller, same as the one `validateCommand` just checked
 * against) is threaded through for its `mealPlanning.templates` data.
 */
async function applyCommand(
  db: CoachFirestore,
  uid: string,
  command: ProposedCommand,
  context: CoachContext,
): Promise<void> {
  const base = `users/${uid}`;
  switch (command.type) {
    case 'nutritionTargetChange': {
      await db.setDoc(`${base}/nutritionGoals/goals`, {
        dailyCalories: command.dailyCalories,
        proteinG: command.proteinG,
        carbsG: command.carbsG,
        fatG: command.fatG,
      });
      return;
    }
    case 'goalChange': {
      const now = new Date().toISOString();
      if (command.goalId === null) {
        const id = newDocId();
        await db.setDoc(`${base}/goals/${id}`, {
          name: command.name,
          category: command.category,
          status: command.status,
          priority: command.priority,
          targetValue: command.targetValue,
          unit: command.unit,
          createdAt: now,
          updatedAt: now,
        });
      } else {
        await db.updateDoc(`${base}/goals/${command.goalId}`, {
          name: command.name,
          category: command.category,
          status: command.status,
          priority: command.priority,
          targetValue: command.targetValue,
          unit: command.unit,
          updatedAt: now,
        });
      }
      return;
    }
    case 'habitChange': {
      const now = new Date().toISOString();
      if (command.habitId === null) {
        const id = newDocId();
        await db.setDoc(`${base}/habits/${id}`, {
          name: command.name,
          cadence: command.cadence,
          timesPerWeek: command.timesPerWeek,
          archived: command.archived,
          createdAt: now,
        });
      } else {
        await db.updateDoc(`${base}/habits/${command.habitId}`, {
          name: command.name,
          cadence: command.cadence,
          timesPerWeek: command.timesPerWeek,
          archived: command.archived,
        });
      }
      return;
    }
    case 'workoutChange':
      // Advisory-only; no protected write target exists for this type.
      return;
    case 'mealPlanChange': {
      const now = new Date().toISOString();
      const cost = computeMealPlanCost(command.items, context.mealPlanning.templates);
      const currency = context.mealPlanning.budget?.currency ?? 'USD';
      const planData = {
        name: command.name,
        periodType: command.periodType,
        items: cost.lines,
        totalCost: cost.totalCost,
        totalCalories: cost.totalCalories,
        totalProteinG: cost.totalProteinG,
        proteinPerCurrencyUnit: cost.proteinPerCurrencyUnit,
        currency,
        source: 'aiProposal',
        updatedAt: now,
      };
      if (command.planId === null) {
        const id = newDocId();
        await db.setDoc(`${base}/mealPlans/${id}`, { ...planData, createdAt: now });
      } else {
        await db.updateDoc(`${base}/mealPlans/${command.planId}`, planData);
      }
      return;
    }
  }
}

/**
 * Re-validates a recommendation's proposed command from scratch — against
 * freshly-read context, using the same pure `validateCommand` the
 * generation path used for its (purely informational) preliminary check —
 * and only then applies the mutation plus writes the `coachEvents` audit
 * record. Never trusts `preliminaryValidation` stored on the recommendation
 * doc, or any validation result supplied by the caller: that value could be
 * stale (context may have changed since generation) or, since it would
 * otherwise arrive from `request.data`, forgeable by a malicious client.
 */
export async function handleCommandHandler(
  uid: string,
  recommendationId: string,
  decision: CoachDecision,
  db: CoachFirestore,
): Promise<HandleCommandResult> {
  const base = `users/${uid}`;
  const doc = (await db.getDoc(`${base}/coachRecommendations/${recommendationId}`)) as RecommendationDoc | null;
  if (doc === null) {
    throw new Error(`Recommendation ${recommendationId} not found.`);
  }

  const eventId = newDocId();
  const command = doc.proposedCommand;

  if (decision === 'reject' || command === null) {
    const outcome: CoachEventOutcome = 'rejectedByUser';
    const reason = command === null ? 'Recommendation had no proposed command to apply.' : 'User rejected the proposal.';
    await db.setDoc(`${base}/coachEvents/${eventId}`, {
      recommendationId,
      command,
      decision,
      outcome,
      reason,
      createdAt: new Date().toISOString(),
    });
    await db.updateDoc(`${base}/coachRecommendations/${recommendationId}`, { status: 'rejected' });
    return { outcome, reason };
  }

  // decision === 'approve' and a command is present: re-validate against a
  // freshly-built context before ever writing anything protected.
  const freshContext = await buildCoachContext(db, uid);
  const validation = validateCommand(command, freshContext);

  if (validation.result === 'reject') {
    const outcome: CoachEventOutcome = 'rejectedByValidation';
    await db.setDoc(`${base}/coachEvents/${eventId}`, {
      recommendationId,
      command,
      decision,
      outcome,
      reason: validation.reason,
      createdAt: new Date().toISOString(),
    });
    await db.updateDoc(`${base}/coachRecommendations/${recommendationId}`, { status: 'rejected' });
    return { outcome, reason: validation.reason };
  }

  // 'allow' or 'requireApproval': the user's explicit 'approve' decision
  // satisfies the approval requirement in both cases.
  //
  // The target document (a goal/habit/meal plan being *updated*, i.e. an
  // update-path command with a non-null id) may have been deleted between
  // when the recommendation was generated and now — the real Admin SDK's
  // `.update()` throws NOT_FOUND in that case (see `adminFirestore.ts`).
  // Catch that here rather than letting it propagate past the audit-write:
  // a deleted target is a legitimate, expected race, not a 500.
  try {
    await applyCommand(db, uid, command, freshContext);
  } catch (error) {
    const outcome: CoachEventOutcome = 'failed';
    const reason = `Could not apply command: its target document no longer exists (${
      error instanceof Error ? error.message : String(error)
    }).`;
    await db.setDoc(`${base}/coachEvents/${eventId}`, {
      recommendationId,
      command,
      decision,
      outcome,
      reason,
      createdAt: new Date().toISOString(),
    });
    // RecommendationStatus on the client only knows pending/accepted/
    // rejected (see lib/features/coach/domain/coach_recommendation.dart) —
    // 'rejected' is the closest accurate status for "this can no longer be
    // applied"; the coachEvents outcome ('failed') is what distinguishes
    // this case from a user- or validation-rejection for anyone auditing.
    await db.updateDoc(`${base}/coachRecommendations/${recommendationId}`, { status: 'rejected' });
    return { outcome, reason };
  }

  const outcome: CoachEventOutcome = 'applied';
  await db.setDoc(`${base}/coachEvents/${eventId}`, {
    recommendationId,
    command,
    decision,
    outcome,
    reason: validation.reason,
    createdAt: new Date().toISOString(),
  });
  await db.updateDoc(`${base}/coachRecommendations/${recommendationId}`, { status: 'accepted' });
  return { outcome, reason: validation.reason };
}

export const handleCommand = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Must be signed in.');
  }
  const recommendationId = request.data?.recommendationId as string | undefined;
  const decision = request.data?.decision as CoachDecision | undefined;
  if (!recommendationId || (decision !== 'approve' && decision !== 'reject')) {
    throw new HttpsError('invalid-argument', 'Missing recommendationId or invalid decision.');
  }
  try {
    return await handleCommandHandler(uid, recommendationId, decision, createAdminCoachFirestore());
  } catch (error) {
    console.error('handleCommand failed', error);
    throw new HttpsError('internal', 'Could not process the coach decision.');
  }
});
