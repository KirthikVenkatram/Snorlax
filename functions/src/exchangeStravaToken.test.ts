import * as admin from 'firebase-admin';
import { exchangeCodeHandler } from './exchangeStravaToken';
import * as stravaClient from './stravaClient';

jest.mock('./stravaClient');
jest.mock('firebase-admin', () => {
  const firestoreMock = {
    collection: jest.fn().mockReturnThis(),
    doc: jest.fn().mockReturnThis(),
    set: jest.fn().mockResolvedValue(undefined),
  };
  // The real `firebase-admin` export for `firestore` is a callable function
  // that also carries static namespace members (e.g. `FieldValue`). Mirror
  // that shape here so `admin.firestore.FieldValue.serverTimestamp()` works.
  const firestoreFn = Object.assign(() => firestoreMock, {
    FieldValue: { serverTimestamp: jest.fn(() => 'mock-server-timestamp') },
  });
  return {
    firestore: firestoreFn,
    apps: [],
    initializeApp: jest.fn(),
  };
});

describe('exchangeCodeHandler', () => {
  it('exchanges the code, stores the refresh token, and returns connected: true', async () => {
    (stravaClient.exchangeCode as jest.Mock).mockResolvedValue({
      athlete: { id: 12345 },
      refresh_token: 'refresh-abc',
      access_token: 'access-abc',
      expires_at: 1893456000,
    });

    const result = await exchangeCodeHandler('uid-1', 'auth-code-xyz');

    expect(stravaClient.exchangeCode).toHaveBeenCalledWith('auth-code-xyz');
    expect(result).toEqual({ connected: true });

    const firestoreMock = admin.firestore() as unknown as {
      collection: jest.Mock;
      doc: jest.Mock;
      set: jest.Mock;
    };
    expect(firestoreMock.collection).toHaveBeenCalledWith('users');
    expect(firestoreMock.doc).toHaveBeenCalledWith('uid-1');
    expect(firestoreMock.set).toHaveBeenCalledWith(
      expect.objectContaining({
        athleteId: 12345,
        refreshToken: 'refresh-abc',
      }),
      expect.anything(),
    );
  });

  it('throws if the Strava token exchange fails', async () => {
    (stravaClient.exchangeCode as jest.Mock).mockRejectedValue(new Error('bad code'));

    await expect(exchangeCodeHandler('uid-1', 'bad-code')).rejects.toThrow('bad code');
  });
});
