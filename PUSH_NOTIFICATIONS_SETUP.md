# Push Notifications — Setup Checklist

The code is fully wired up for four notification triggers: someone paid you, a payment failed, a new expense was added, and someone joined a group. Everything is designed to fail quietly (no crashes, no broken screens) until the steps below are done — but nothing will actually *send* until they are. These steps all happen outside this repo, in accounts only you can create, so they can't be done for you.

## 1. Create a Firebase project (free, ~2 minutes)

1. Go to [console.firebase.google.com](https://console.firebase.google.com) and sign in with your Google account.
2. Click "Add project", name it (e.g. "SplitNaija"), and finish the wizard. You can decline Google Analytics — not needed here.

## 2. Register the Android app

1. In the Firebase console, click the Android icon to add an app.
2. **Package name**: enter exactly `com.example.splitnaija` — that's what's currently in `mobile/android/app/build.gradle.kts` as the `applicationId`. If you rename that before shipping, redo this step to match.
3. Download the `google-services.json` file it offers.
4. Place it at `mobile/android/app/google-services.json` (that exact path — next to `build.gradle.kts`).

Nothing else in the Android project needs touching — the Gradle wiring for this is already in place and only activates once that file exists.

## 3. Get a service account key for the backend

1. In the Firebase console: gear icon → **Project settings** → **Service accounts** tab.
2. Click "Generate new private key" — downloads a JSON file. Keep it private; it's a real credential.
3. Open that file, copy its entire contents, and set it as one environment variable in `backend/.env`:

   ```
   FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"...", ...entire file as one line...}
   ```

   (Most editors can select-all + join-lines, or just paste the whole JSON object between the quotes — it doesn't need to be minified, multi-line works fine as long as it's valid JSON assigned to that one variable.)

## 4. Install the new dependencies

```bash
cd backend && npm install
cd ../mobile && flutter pub get
```

`npm install` picks up `firebase-admin` (added to `backend/package.json`). `flutter pub get` picks up `firebase_core` and `firebase_messaging`.

## 5. Apply the database migration

```bash
cd backend && npx prisma migrate dev
```

This adds the `pushTokens` column to `User` (already written as a migration file — this just applies it and regenerates the Prisma client, which is also needed for the `pushTokens` references in the code to type-check).

## 6. Restart and test

1. Restart the backend (`npm run dev`).
2. `flutter run` the app on an Android device or emulator with Google Play services (a plain AVD without Play Store won't get real pushes — use one with the Play Store icon, or a physical device).
3. First launch will prompt for notification permission — accept it.
4. Trigger any of the four events to test: add an expense that splits with someone else, join a group with an existing member in it, or (once your Paystack account can actually send transfers) pay/get paid.

If nothing arrives, check the backend console — `sendPushToUser`/`sendPushToUsers` log every attempt, including exactly why one was skipped (not configured, no token on file, Firebase rejected it, etc.).

## iOS — deferred

Not wired up yet, per your call to hold off until you have an Apple Developer Program membership ($99/year — required by Apple for any app sending push notifications, not specific to this stack). When you're ready:

1. Enroll in the Apple Developer Program and generate an APNs Auth Key (Certificates, Identifiers & Profiles → Keys).
2. Upload that key to Firebase (Project settings → Cloud Messaging → Apple app configuration).
3. Register an iOS app in the same Firebase project, download `GoogleService-Info.plist`, drop it into `mobile/ios/Runner/`.
4. No new Flutter packages needed — `firebase_messaging` already supports iOS; it's purely the Apple-side credentials that are missing.
