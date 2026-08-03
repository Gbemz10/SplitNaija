import { prisma } from "../lib/prisma";

// Push notifications are optional infrastructure: this service is a safe
// no-op (logs and returns) until BOTH `npm install` has pulled in
// firebase-admin AND FIREBASE_SERVICE_ACCOUNT_JSON is set, so nothing else
// in the app — including the server just being able to start up — depends
// on push actually being configured. See PUSH_NOTIFICATIONS_SETUP.md in the
// repo root for the external steps (a Firebase project, an Android app
// registration, a service account key) — none of which can be done from
// inside this repo.
//
// firebase-admin is loaded lazily via require() inside a try/catch, not a
// top-level import, specifically so that restarting the server *before*
// running `npm install` doesn't crash it outright with "Cannot find module"
// — every route that might trigger a notification (new expense, settlement
// webhook, group join) would otherwise go down with it. A loose local type
// stands in for firebase-admin's real types so this file doesn't need the
// package's type declarations present just to compile.
interface FirebaseAdminLike {
  apps: unknown[];
  initializeApp(opts: { credential: unknown }): unknown;
  credential: { cert(serviceAccount: object): unknown };
  messaging(): {
    sendEachForMulticast(message: {
      tokens: string[];
      notification: { title: string; body: string };
      data?: Record<string, string>;
    }): Promise<{ responses: Array<{ success: boolean; error?: { code?: string } }> }>;
  };
}

function loadFirebaseAdmin(): FirebaseAdminLike | null {
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    return require("firebase-admin") as FirebaseAdminLike;
  } catch {
    return null;
  }
}

let cachedReady: boolean | undefined;

function ensureReady(): FirebaseAdminLike | null {
  const admin = loadFirebaseAdmin();
  if (!admin) {
    if (cachedReady !== false) {
      console.log("[push] firebase-admin isn't installed yet (run `npm install` in backend/) — push notifications are disabled.");
    }
    cachedReady = false;
    return null;
  }

  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!raw) {
    if (cachedReady !== false) {
      console.log("[push] FIREBASE_SERVICE_ACCOUNT_JSON not set — push notifications are disabled.");
    }
    cachedReady = false;
    return null;
  }

  if (admin.apps.length === 0) {
    try {
      admin.initializeApp({ credential: admin.credential.cert(JSON.parse(raw)) });
    } catch (err) {
      console.error("[push] failed to initialize firebase-admin — check FIREBASE_SERVICE_ACCOUNT_JSON:", err);
      cachedReady = false;
      return null;
    }
  }

  cachedReady = true;
  return admin;
}

export interface PushNotification {
  title: string;
  body: string;
  // Arbitrary extra data delivered alongside the notification — e.g. a
  // groupId so tapping it can deep-link straight to that group instead of
  // just opening the app to its home screen. Every value must be a string;
  // FCM's data payload doesn't support nested objects or other types.
  data?: Record<string, string>;
}

/**
 * Sends a push notification to every device a user is signed in on. Safe to
 * call unconditionally from anywhere — it no-ops (just logs) if push isn't
 * installed/configured, and silently prunes any device token Firebase
 * reports as dead/unregistered so the array doesn't accumulate stale
 * entries forever.
 */
export async function sendPushToUser(userId: string, notification: PushNotification): Promise<void> {
  const admin = ensureReady();
  if (!admin) {
    console.log(`[push] (disabled) would have sent to user ${userId}: ${notification.title}`);
    return;
  }

  const user = await prisma.user.findUnique({ where: { id: userId }, select: { pushTokens: true } });
  if (!user || user.pushTokens.length === 0) return;

  let response;
  try {
    response = await admin.messaging().sendEachForMulticast({
      tokens: user.pushTokens,
      notification: { title: notification.title, body: notification.body },
      data: notification.data,
    });
  } catch (err) {
    console.error("[push] sendEachForMulticast failed:", err);
    return;
  }

  const deadTokens: string[] = [];
  response.responses.forEach((r, i) => {
    const code = r.error?.code;
    if (!r.success && (code === "messaging/invalid-registration-token" || code === "messaging/registration-token-not-registered")) {
      deadTokens.push(user.pushTokens[i]);
    }
  });

  if (deadTokens.length > 0) {
    await prisma.user.update({
      where: { id: userId },
      data: { pushTokens: { set: user.pushTokens.filter((t) => !deadTokens.includes(t)) } },
    });
  }
}

/**
 * Same as sendPushToUser, but for a batch of recipients (e.g. every other
 * participant on a new expense) — fires them concurrently rather than
 * making the caller await one at a time.
 */
export async function sendPushToUsers(userIds: string[], notification: PushNotification): Promise<void> {
  await Promise.all(userIds.map((id) => sendPushToUser(id, notification)));
}
