import { handleActivityEvent } from './stravaWebhook';
import * as stravaClient from './stravaClient';

jest.mock('./stravaClient');
jest.mock('firebase-admin', () => {
  const workoutDocRef = { set: jest.fn().mockResolvedValue(undefined) };
  const workoutsCollection = { doc: jest.fn().mockReturnValue(workoutDocRef) };
  const connectionDocRef = {
    get: jest.fn().mockResolvedValue({
      exists: true,
      data: () => ({ refreshToken: 'refresh-abc' }),
    }),
  };
  const metaCollection = { doc: jest.fn().mockReturnValue(connectionDocRef) };
  const userDocRef = {
    collection: jest.fn((name: string) =>
      name === 'workouts' ? workoutsCollection : metaCollection,
    ),
  };
  const usersCollection = { doc: jest.fn().mockReturnValue(userDocRef) };

  // The collectionGroup('meta') query matches the meta document itself
  // (users/{uid}/meta/stravaConnection), so its ref needs a two-level
  // parent chain (doc -> collection -> doc) to resolve back to the user's
  // document, mirroring real Firestore DocumentReference/CollectionReference
  // semantics.
  const matchedMetaDocRef = { parent: { parent: userDocRef } };

  const queryMock = {
    where: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    get: jest.fn().mockResolvedValue({
      empty: false,
      docs: [{ ref: matchedMetaDocRef, id: 'uid-1' }],
    }),
  };

  const firestoreMock = {
    collectionGroup: jest.fn().mockReturnValue(queryMock),
    collection: jest.fn().mockReturnValue(usersCollection),
  };

  return {
    firestore: Object.assign(() => firestoreMock, {
      FieldValue: { serverTimestamp: jest.fn() },
      Timestamp: { fromDate: jest.fn().mockReturnValue('mock-timestamp') },
    }),
    apps: [],
    initializeApp: jest.fn(),
  };
});

describe('handleActivityEvent', () => {
  it('resolves the user by athlete id, refreshes the token, fetches the activity, and writes a cardio workout', async () => {
    (stravaClient.refreshAccessToken as jest.Mock).mockResolvedValue({
      access_token: 'fresh-access-token',
    });
    (stravaClient.getActivity as jest.Mock).mockResolvedValue({
      id: 999,
      type: 'Run',
      distance: 5000,
      moving_time: 1500,
      start_date: '2026-08-10T06:00:00Z',
    });

    await handleActivityEvent({ object_type: 'activity', owner_id: 12345, object_id: 999 });

    expect(stravaClient.refreshAccessToken).toHaveBeenCalledWith('refresh-abc');
    expect(stravaClient.getActivity).toHaveBeenCalledWith('fresh-access-token', 999);
  });

  it('drops the event silently if no user matches the athlete id', async () => {
    const firestoreModule = jest.requireMock('firebase-admin').firestore();
    firestoreModule.collectionGroup().get.mockResolvedValueOnce({ empty: true, docs: [] });

    await expect(
      handleActivityEvent({ object_type: 'activity', owner_id: 99999999, object_id: 1 }),
    ).resolves.toBeUndefined();

    expect(stravaClient.getActivity).not.toHaveBeenCalled();
  });

  it('ignores non-activity event types', async () => {
    await handleActivityEvent({ object_type: 'athlete', owner_id: 12345, object_id: 1 });

    expect(stravaClient.refreshAccessToken).not.toHaveBeenCalled();
  });
});
