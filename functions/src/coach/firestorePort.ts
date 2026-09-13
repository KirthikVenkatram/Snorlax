/**
 * Minimal Firestore access port used by `coach/` code.
 *
 * `buildCoachContext`, `generateRecommendation`, and `handleCommand` depend
 * on this narrow interface instead of the `firebase-admin` Firestore SDK
 * directly, so unit tests can supply a small in-memory fake (no emulator
 * required) while production wiring (`adminFirestore.ts`) supplies the real
 * Admin SDK. This is also the only surface these modules use to read/write
 * Firestore, keeping the set of paths they can touch easy to audit.
 */

export interface DocSnapshot {
  id: string;
  data: Record<string, unknown>;
}

export interface CoachFirestore {
  /** Reads one document by full slash-separated path. Null if it doesn't exist. */
  getDoc(path: string): Promise<Record<string, unknown> | null>;
  /** Reads every document in a collection by full slash-separated path. */
  getCollection(path: string): Promise<DocSnapshot[]>;
  /** Overwrites a document (create-or-replace) by full slash-separated path. */
  setDoc(path: string, data: Record<string, unknown>): Promise<void>;
  /** Merges fields into an existing document by full slash-separated path. */
  updateDoc(path: string, data: Record<string, unknown>): Promise<void>;
}

/** Generates a random id for a new document, independent of any Firestore SDK. */
export function newDocId(): string {
  return globalThis.crypto.randomUUID();
}
