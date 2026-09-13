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
   * Phase 8 (meal planning) has not landed yet, so there is no meal-plan
   * data model to ground this operation in. It still routes through the
   * real provider (so the seam is real, not a hardcoded stub), but callers
   * should treat its output as provisional until Phase 8 defines the
   * expected shape. See docs/superpowers/ISSUES.md, "Phase 7".
   */
  generateMealPlanProposal(prompt: string): Promise<string>;
}

export const defaultAiProvider: AiProvider = {
  generateCoachRecommendation: (prompt) => llmClient.generateText(prompt),
  summarizeProgress: (prompt) => llmClient.generateText(prompt),
  generateMealPlanProposal: (prompt) => llmClient.generateText(prompt),
};
