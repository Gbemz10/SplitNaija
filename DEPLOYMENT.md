# Deploying SplitNaija So People Can Try the APK

Right now the backend only runs on your laptop at `localhost` — an APK installed on someone else's phone has no way to reach that. This gets you a real, stable backend URL (free), then an APK built to point at it.

## 1. Push your backend changes

Only the mobile frontend got pushed to GitHub last time — all the backend fixes since (password auth, delete account, push notification scaffolding, the settlement simulation flag) are still sitting locally uncommitted. Render deploys from GitHub, so:

```bash
cd /path/to/splitnaija-backend
git add backend/ render.yaml
git commit -m "Backend fixes + Render deployment config"
git push origin main
```

## 2. Create a free Postgres database (Neon)

Render's own free Postgres expires after 90 days; Neon's free tier doesn't expire, so the database outlives whatever this demo turns into.

1. Go to [neon.tech](https://neon.tech), sign up (no card needed), create a project (any region/name).
2. On the project dashboard, copy the **connection string** — it looks like `postgresql://user:password@ep-xxxx.neon.tech/dbname?sslmode=require`. You'll paste this into Render in step 4.

## 3. Create a free Render account

Go to [render.com](https://render.com) and sign up (no card needed for the free tier).

## 4. Deploy the backend

1. In the Render dashboard: **New +** → **Blueprint**.
2. Connect your GitHub account and pick the `SplitNaija` repo. Render will find `render.yaml` at the repo root automatically.
3. It'll show one service to create (`splitnaija-backend`) and ask you to fill in the secrets it didn't want to guess:
   - `DATABASE_URL` — paste the Neon connection string from step 2.
   - `PAYSTACK_SECRET_KEY` — your existing test key from `backend/.env`.
   - `TERMII_API_KEY` — leave blank for now (see the OTP note below), or fill in if you already have one.
4. Click deploy. First build takes a few minutes (it's running `npm install`, `prisma generate`, `tsc`, then applying migrations).
5. Once live, Render gives you a URL like `https://splitnaija-backend.onrender.com` — that's your public backend.

**Free-tier heads-up**: the service sleeps after 15 minutes with no requests, and the *first* request after that takes 30–60 seconds to wake it back up. Don't mistake that for the app being broken — just a cold start. Everything after that first request is normal speed.

## 5. The OTP problem

Signup and login both require a real SMS OTP. Without a Termii API key, codes only ever show up in Render's log stream (Dashboard → your service → **Logs**) — nowhere a tester can see them. Two ways to handle this for now:

- **You relay it manually**: watch the Render logs while a tester signs up, read them the code over a call/WhatsApp. Fine for a handful of testers.
- **Get a real Termii key**: sign up at [termii.com](https://termii.com), get an API key, add it as the `TERMII_API_KEY` env var in Render's dashboard (Settings → Environment) — then OTPs actually arrive by SMS and nobody needs you in the loop.

## 6. Build the APK

```bash
cd mobile
flutter build apk --release --dart-define=API_BASE_URL=https://splitnaija-backend.onrender.com
```

(Swap in your actual Render URL from step 4.) The file lands at:

```
mobile/build/app/outputs/flutter-apk/app-release.apk
```

This is a single universal APK (works on any Android device/architecture) signed with the debug key that's already configured in `android/app/build.gradle.kts` — fine for sideloading testers, not something you'd submit to the Play Store, but that's not what you're doing here.

## 7. Get it onto testers' phones

The `.apk` file is just a file — send it however's easiest (Google Drive link, WhatsApp, email). Each tester needs to allow "install unknown apps" for whatever app they downloaded it through (Android will prompt them the first time they try to open it). If you want something smoother than passing a raw file around, [Firebase App Distribution](https://firebase.google.com/docs/app-distribution) or [Diawi](https://www.diawi.com/) will host it and give testers a QR code / link to install from directly — worth it if you're sharing with more than a couple of people.

## Later: the Paystack webhook

Not urgent while `PAYSTACK_SIMULATE_TRANSFERS=true` (no real transfers happen, so no webhook ever fires). Once your business is verified and you flip that back to `false`, update the webhook URL in your Paystack dashboard to `https://<your-render-url>/settlements/webhook/paystack` so real transfer confirmations reach the deployed backend instead of your old `localhost` one.
