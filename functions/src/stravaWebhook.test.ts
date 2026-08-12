import { handleActivityEvent } from './stravaWebhook';
import * as stravaClient from './stravaClient';

jest.mock('./stravaClient');
jest.mock('firebase-admin', () => {
  const workoutDocRef = { set: jest.fn().mockResolvedValue(undefined) };
  const workoutsCollection = { doc: jest.fn().mockReturnValue(workoutDocRef) };
  const connectionDocRef = {
    set: jest.fn().mockResolvedValue(undefined),
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
  // semantics. `set` on that same ref is how the rotated refresh token is
  // written back.
  const matchedMetaDocRef = {
    parent: { parent: userDocRef },
    set: jest.fn().mockResolvedValue(undefined),
  };
  const matchedMetaDoc = {
    ref: matchedMetaDocRef,
    id: 'stravaConnection',
    data: () => ({ athleteId: 12345, refreshToken: 'refresh-abc' }),
  };

  const queryMock = {
    where: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    get: jest.fn().mockResolvedValue({
      empty: false,
      docs: [matchedMetaDoc],
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
    // Exposed for assertions in the tests below.
    __mocks: { workoutDocRef, workoutsCollection, matchedMetaDocRef },
  };
});

const adminMock = jest.requireMock('firebase-admin');
const { workoutDocRef, workoutsCollection, matchedMetaDocRef } = adminMock.__mocks;

describe('handleActivityEvent', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    (stravaClient.refreshAccessToken as jest.Mock).mockResolvedValue({
      access_token: 'fresh-access-token',
      refresh_token: 'refresh-abc',
    });
    (stravaClient.getActivity as jest.Mock).mockResolvedValue({
      id: 999,
      type: 'Run',
      distance: 5000,
      moving_time: 1500,
      start_date: '2026-08-10T06:00:00Z',
    });
  });

  it('resolves the user by athlete id, refreshes the token, fetches the activity, and writes a cardio workout', async () => {
    await handleActivityEvent({
      object_type: 'activity',
      aspect_type: 'create',
      owner_id: 12345,
      object_id: 999,
    });

    expect(stravaClient.refreshAccessToken).toHaveBeenCalledWith('refresh-abc');
    expect(stravaClient.getActivity).toHaveBeenCalledWith('fresh-access-token', 999);

    // Deterministic id derived from the Strava activity id makes redelivery
    // idempotent instead of duplicating the workout.
    expect(workoutsCollection.doc).toHaveBeenCalledWith('strava_999');
    expect(workoutDocRef.set).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'cardio',
        source: 'strava',
        distanceKm: 5,
        durationMinutes: 25,
        paceMinPerKm: 5,
        stravaActivityId: '999',
      }),
      { merge: true },
    );
  });

  it('persists a rotated refresh token', async () => {
    (stravaClient.refreshAccessToken as jest.Mock).mockResolvedValue({
      access_token: 'fresh-access-token',
      refresh_token: 'rotated-refresh-token',
    });

    await handleActivityEvent({
      object_type: 'activity',
      aspect_type: 'create',
      owner_id: 12345,
      object_id: 999,
    });

    expect(matchedMetaDocRef.set).toHaveBeenCalledWith(
      { refreshToken: 'rotated-refresh-token' },
      { merge: true },
    );
  });

  it('drops the event silently if no user matches the athlete id', async () => {
    const firestoreModule = adminMock.firestore();
    firestoreModule.collectionGroup().get.mockResolvedValueOnce({ empty: true, docs: [] });

    await expect(
      handleActivityEvent({
        object_type: 'activity',
        aspect_type: 'create',
        owner_id: 99999999,
        object_id: 1,
      }),
    ).resolves.toBeUndefined();

    expect(stravaClient.getActivity).not.toHaveBeenCalled();
    expect(workoutDocRef.set).not.toHaveBeenCalled();
  });

  it('ignores non-activity event types', async () => {
    await handleActivityEvent({
      object_type: 'athlete',
      aspect_type: 'create',
      owner_id: 12345,
      object_id: 1,
    });

    expect(stravaClient.refreshAccessToken).not.toHaveBeenCalled();
    expect(stravaClient.getActivity).not.toHaveBeenCalled();
  });

  it.each(['update', 'delete'])('ignores %s events instead of writing a workout', async (aspectType) => {
    await handleActivityEvent({
      object_type: 'activity',
      aspect_type: aspectType,
      owner_id: 12345,
      object_id: 999,
    });

    expect(stravaClient.refreshAccessToken).not.toHaveBeenCalled();
    expect(stravaClient.getActivity).not.toHaveBeenCalled();
    expect(workoutDocRef.set).not.toHaveBeenCalled();
  });
});
