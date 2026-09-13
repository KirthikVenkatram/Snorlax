import { CoachFirestore, DocSnapshot } from './firestorePort';

/**
 * Minimal in-memory `CoachFirestore` for unit tests. Not a jest test file
 * itself (no `.test.ts` suffix) — imported by the coach test suites so each
 * one doesn't hand-roll its own fake.
 */
export function createFakeCoachFirestore(seed: Record<string, Record<string, unknown>> = {}): CoachFirestore & {
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
      const existing = store.get(path) ?? {};
      store.set(path, { ...existing, ...data });
    },
    dump() {
      return Object.fromEntries(store.entries());
    },
  };
}
