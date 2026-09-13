import { CoachFirestore, DocSnapshot } from './firestorePort';

/**
 * Minimal in-memory `CoachFirestore` for unit tests. Not a jest test file
 * itself (no `.test.ts` suffix) — imported by the coach test suites so each
 * one doesn't hand-roll its own fake.
 */
export interface FakeCoachFirestoreOptions {
  /**
   * When true, `updateDoc` throws on a missing document instead of silently
   * upserting it, mirroring the real Admin SDK's `.update()` behavior
   * (`adminFirestore.ts`), which throws NOT_FOUND when the target doc
   * doesn't exist. Defaults to false to preserve the lenient behavior most
   * existing tests rely on; pass `true` specifically to test the
   * deleted-target-at-approval-time race in `handleCommand.ts`.
   */
  strictUpdate?: boolean;
}

export function createFakeCoachFirestore(
  seed: Record<string, Record<string, unknown>> = {},
  options: FakeCoachFirestoreOptions = {},
): CoachFirestore & {
  dump(): Record<string, Record<string, unknown>>;
} {
  const store = new Map<string, Record<string, unknown>>(Object.entries(seed));

  function collectionOf(path: string): DocSnapshot[] {
    const prefix = `${path}/`;
    const results: DocSnapshot[] = [];
    for (const [docPath, data] of store.entries()) {
      if (!docPath.startsWith(prefix)) continue;
      const rest = docPath.slice(prefix.length);
      if (rest.includes('/')) continue; // only direct children are "documents" in this collection
      results.push({ id: rest, data });
    }
    return results;
  }

  return {
    async getDoc(path) {
      return store.has(path) ? store.get(path)! : null;
    },
    async getCollection(path) {
      return collectionOf(path);
    },
    async setDoc(path, data) {
      store.set(path, data);
    },
    async updateDoc(path, data) {
      const existing = store.get(path);
      if (existing === undefined) {
        if (options.strictUpdate) {
          const error = new Error(`No document to update: ${path}`);
          (error as Error & { code?: number }).code = 5; // gRPC NOT_FOUND, matching Admin SDK's error.code
          throw error;
        }
        store.set(path, { ...data });
        return;
      }
      store.set(path, { ...existing, ...data });
    },
    dump() {
      return Object.fromEntries(store.entries());
    },
  };
}
