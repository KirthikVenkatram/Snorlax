import * as llmClient from '../llmClient';

/**
 * Typed seam over `llmClient.generateText`'s Groq-primary/NVIDIA-NIM-fallback
 * implementation. Coach code calls these named operations instead of
 * `llmClient` directly, so:
 *   - tests mock this interface (or `llmClient`, the actual provider
 *     boundary) rather than validation/business logic built on top of it;
 *   - a future swap to a different model/provider per-operation doesn't
 *     ripple through `coach/`.
 *
 * Every operation returns the raw provider text response. Callers are
 * responsible for extracting/validating structured output — this interface
 * makes no promise about response shape.
 */
export interface AiProvider {
  generateCoachRecommendation(prompt: string): Promise<string>;
  summarizeProgress(prompt: string): Promise<string>;
  /**
   * As of Phase 8, called by `coach/generateMealPlanRecommendation.ts` with
   * a budget/meal-template-grounded prompt. Like every `AiProvider`
   * operation, this returns raw provider text — the caller is responsible
   * for parsing/validating it (`ai/schemas.ts`'s `parseMealPlanRecommendation`)
   * and never trusts any cost/nutrition numbers the model might include; only
   * `templateId`/`servings` pairs are accepted from the proposal, with cost
   * computed deterministically server-side. See docs/superpowers/ISSUES.md,
   * "Phase 8".
   */
  generateMealPlanProposal(prompt: string): Promise<string>;
}

export const defaultAiProvider: AiProvider = {
  generateCoachRecommendation: (prompt) => llmClient.generateText(prompt),
  summarizeProgress: (prompt) => llmClient.generateText(prompt),
  generateMealPlanProposal: (prompt) => llmClient.generateText(prompt),
};
