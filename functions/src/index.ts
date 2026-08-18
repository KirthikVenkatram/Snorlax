import * as admin from 'firebase-admin';

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export { exchangeStravaToken } from './exchangeStravaToken';
export { stravaWebhook } from './stravaWebhook';
export { searchFood } from './searchFood';
export { parseFoodText } from './parseFoodText';
export { estimateNutrition } from './estimateNutrition';
