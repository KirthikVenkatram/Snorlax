import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as stravaClient from './stravaClient';

export async function exchangeCodeHandler(uid: string, code: string) {
  const tokenResponse = await stravaClient.exchangeCode(code);

  await admin
    .firestore()
    .collection('users')
    .doc(uid)
    .collection('meta')
    .doc('stravaConnection')
    .set(
      {
        athleteId: tokenResponse.athlete.id,
        refreshToken: tokenResponse.refresh_token,
        connectedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  return { connected: true };
}

export const exchangeStravaToken = onCall(
  { secrets: ['STRAVA_CLIENT_ID', 'STRAVA_CLIENT_SECRET'] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }

    const code = request.data?.code as string | undefined;
    if (!code) {
      throw new HttpsError('invalid-argument', 'Missing authorization code.');
    }

    return exchangeCodeHandler(uid, code);
  },
);
