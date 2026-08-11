const STRAVA_CLIENT_ID = process.env.STRAVA_CLIENT_ID ?? '';
const STRAVA_CLIENT_SECRET = process.env.STRAVA_CLIENT_SECRET ?? '';

export interface StravaTokenResponse {
  athlete: { id: number };
  access_token: string;
  refresh_token: string;
  expires_at: number;
}

export async function exchangeCode(code: string): Promise<StravaTokenResponse> {
  const response = await fetch('https://www.strava.com/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: STRAVA_CLIENT_ID,
      client_secret: STRAVA_CLIENT_SECRET,
      code,
      grant_type: 'authorization_code',
    }),
  });

  if (!response.ok) {
    throw new Error(`Strava token exchange failed: ${response.status}`);
  }

  return (await response.json()) as StravaTokenResponse;
}

export async function refreshAccessToken(refreshToken: string): Promise<StravaTokenResponse> {
  const response = await fetch('https://www.strava.com/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: STRAVA_CLIENT_ID,
      client_secret: STRAVA_CLIENT_SECRET,
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
    }),
  });

  if (!response.ok) {
    throw new Error(`Strava token refresh failed: ${response.status}`);
  }

  return (await response.json()) as StravaTokenResponse;
}

export interface StravaActivity {
  id: number;
  type: string;
  distance: number; // meters
  moving_time: number; // seconds
  start_date: string; // ISO 8601
}

export async function getActivity(accessToken: string, activityId: number): Promise<StravaActivity> {
  const response = await fetch(`https://www.strava.com/api/v3/activities/${activityId}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!response.ok) {
    throw new Error(`Strava getActivity failed: ${response.status}`);
  }

  return (await response.json()) as StravaActivity;
}
