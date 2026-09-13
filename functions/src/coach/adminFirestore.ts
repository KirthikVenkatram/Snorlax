import * as admin from 'firebase-admin';
import { CoachFirestore } from './firestorePort';

/**
 * Real `CoachFirestore` backed by the Admin SDK. Only used from the
 * `onCall` wrappers (`generateRecommendation`/`handleCommand` exports), never
 * from unit tests — those supply an in-memory fake implementing the same
 * interface instead.
 */
export function createAdminCoachFirestore(): CoachFirestore {
  const db = admin.firestore();
  return {
    async getDoc(path) {
      const snapshot = await db.doc(path).get();
      return snapshot.exists ? (snapshot.data() as Record<string, unknown>) : null;
    },
    async getCollection(path) {
      const snapshot = await db.collection(path).get();
      return snapshot.docs.map((doc) => ({ id: doc.id, data: doc.data() }));
    },
    async setDoc(path, data) {
      await db.doc(path).set(data);
    },
    async updateDoc(path, data) {
      await db.doc(path).update(data);
    },
  };
}
