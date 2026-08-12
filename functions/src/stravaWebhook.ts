import * as admin from 'firebase-admin';
import { onRequest } from 'firebase-functions/v2/https';
import * as stravaClient from './stravaClient';

const STRAVA_VERIFY_TOKEN = process.env.STRAVA_WEBHOOK_VERIFY_TOKEN ?? '';

interface StravaWebhookEvent {
  object_type: string;
  aspect_type: string; // 'create' | 'update' | 'delete'
  owner_id: number;
  object_id: number;
}

/**
 * Resolves which Firebase user owns the given Strava athlete id, refreshes
 * their access token, fetches the full activity, and writes it as a cardio
 * workout. Silently drops events that don't map to a known user or that
 * aren't activity-creation events — Strava does not usefully retry on our
 * behalf for either case, so throwing would only cause noisy redelivery.
 */
export async function handleActivityEvent(event: StravaWebhookEvent): Promise<void> {
  if (event.object_type !== 'activity') return;
  // Only new activities are ingested. Edits and deletions made in Strava are
  // not mirrored in this phase; without this check they would each create an
  // extra workout document.
  if (event.aspect_type !== 'create') return;

  const firestore = admin.firestore();

  const matches = await firestore
    .collectionGroup('meta')
    .where('athleteId', '==', event.owner_id)
    .limit(1)
    .get();

  if (matches.empty) return;

  const matchedMetaDoc = matches.docs[0];
  const userDocRef = matchedMetaDoc.ref.parent.parent!;
  // The matched document *is* users/{uid}/meta/stravaConnection, so its data
  // is already in hand — no second read required.
  const refreshToken = matchedMetaDoc.data()?.refreshToken as string | undefined;
  if (!refreshToken) {
    console.error('stravaWebhook: matched Strava connection has no refreshToken', {
      athleteId: event.owner_id,
    });
    return;
  }

  const { access_token: accessToken, refresh_token: rotatedRefreshToken } =
    await stravaClient.refreshAccessToken(refreshToken);

  // Strava rotates refresh tokens: persist the new one or every subsequent
  // refresh with the stale token fails.
  if (rotatedRefreshToken && rotatedRefreshToken !== refreshToken) {
    await matchedMetaDoc.ref.set({ refreshToken: rotatedRefreshToken }, { merge: true });
  }

  const activity = await stravaClient.getActivity(accessToken, event.object_id);

  const distanceKm = activity.distance / 1000;
  const durationMinutes = Math.round(activity.moving_time / 60);
  const paceMinPerKm = distanceKm > 0 ? durationMinutes / distanceKm : 0;

  // Intentional simplification for this phase: every Strava-sourced activity is
  // stored as `cardio`, regardless of `activity.type` (e.g. "WeightTraining").
  // Deterministic doc id + merge makes Strava redelivery an idempotent no-op
  // rather than a duplicate workout.
  await userDocRef
    .collection('workouts')
    .doc(`strava_${activity.id}`)
    .set(
      {
        type: 'cardio',
        source: 'strava',
        date: admin.firestore.Timestamp.fromDate(new Date(activity.start_date)),
        durationMinutes,
        distanceKm,
        paceMinPerKm,
        stravaActivityId: String(activity.id),
      },
      { merge: true },
    );
}

export const stravaWebhook = onRequest({ secrets: ['STRAVA_WEBHOOK_VERIFY_TOKEN'] }, (req, res) => {
  if (req.method === 'GET') {
    // Strava's one-time webhook subscription validation handshake.
    const mode = req.query['hub.mode'];
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];

    if (mode === 'subscribe' && token === STRAVA_VERIFY_TOKEN) {
      res.status(200).json({ 'hub.challenge': challenge });
      return;
    }
    res.status(403).send('Verification failed');
    return;
  }

  if (req.method === 'POST') {
    handleActivityEvent(req.body as StravaWebhookEvent)
      .then(() => res.status(200).send('EVENT_RECEIVED'))
      .catch((error) => {
        console.error('stravaWebhook error', error);
        res.status(200).send('EVENT_RECEIVED'); // ack anyway; error is logged, not retried
      });
    return;
  }

  res.status(405).send('Method not allowed');
});
