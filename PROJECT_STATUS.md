# SplitNaija — Project Status

Nigeria-focused, Splitwise-style group expense splitter with in-app naira settlement via Paystack. Backend: Node/Express/TypeScript/Prisma/Postgres. Mobile: Flutter. Money is stored and moved as integer kobo everywhere, never floats.

## How the app works end to end right now

**Getting an account.** A new user lands on the Get Started screen, enters their name and phone number, receives a 6-digit OTP by SMS (via Termii — logged to the console instead if no `TERMII_API_KEY` is set), enters it, then sets a password. That call (`POST /auth/signup`) checks the OTP server-side, creates the User row with a hashed password, and returns a JWT (30-day expiry) plus the user object. The token goes into secure storage; the user object is cached locally so the app has a display name/photo/payout details to show immediately on every screen without a round-trip.

**Logging back in** is just phone + password (`POST /auth/login`) — no OTP needed once an account exists. Forgot password sends a fresh OTP to the phone, and resetting it requires that OTP again (`POST /auth/password/forgot` → `POST /auth/password/reset`) — proving phone ownership since the person doesn't have the old password to prove anything with.

**Session restore:** on app launch, if a token is already in secure storage, the app shows the cached user immediately, then fires `GET /auth/me` in the background to refresh that cache against the server (fixes anything that drifted, e.g. a payout account set up on another device).

**Groups.** From the Groups tab, a user creates a group (becomes its first member — whoever joined earliest is treated as the owner and is the only one who can delete it) or joins one by invite code. Each group row shows member count and this user's own net balance, color-coded. Inside a group: the member list (with real profile photos, not just initials, wherever a member has one), a list of expenses (newest first, tappable into a detail view), and a balances section showing only what actually involves the viewer — either "you're owed" or "you owe," never other members' unrelated balances.

**Adding an expense.** Pick participants, an amount, a split method (equal / custom naira amounts / percentages — user picks who owes what), optionally one of five templates (owambe contribution, ajo/esusu round, shared subscription, rent, generic). The split math always happens server-side (`calculateSplits()`), never trusted from the client, with the last share absorbing any kobo rounding remainder. Only the person who added an expense can delete it.

**Settling up.** The app computes each group's simplified debts (fewest possible transactions, not one-per-expense) and shows "you owe X" or "X owes you" cards. Before anyone can *receive* money, they have to set up a payout account (bank + account number under the Account tab), which Paystack resolves to a real account name before it's saved. Tapping "pay" opens a confirmation sheet, then calls `POST /settlements`, which creates a PENDING settlement and kicks off a real Paystack transfer. The settlement only ever flips to CONFIRMED (or FAILED) off a signature-verified Paystack webhook — never optimistically on the client — so money actually has to move for the app to say it moved. A manual "reconcile" action exists for a settlement stuck PENDING if the webhook never arrives; there's no automatic sweep for that yet.

**Activity tab** is a cross-group feed of everything the signed-in user is actually part of — expenses they paid or split, settlements they sent or received — not everything happening in groups they merely belong to.

**Wallet tab** shows settlement/transaction history.

**Account tab**: edit display name and profile photo, view saved payout account details, change password (current password required, no OTP — they're already signed in), and delete account. Deleting doesn't hard-delete the row (that would corrupt other members' shared expense history) — it scrubs every personal identifier, wipes the password hash so it can never log in again, and tombstones the phone number so it's free for someone else to sign up with.

**Inviting people.** A group's invite code can be copied and shared, or a person can be added by name + phone number directly from the app, which opens WhatsApp with a pre-written invite message and a link to a real branded preview page (shows the group name and member count) — no WhatsApp Business API needed, just a click-to-chat link.

## What's built

**Auth & account**
- Phone + password signup, gated by a real OTP sent via Termii
- Login, forgot/reset password (OTP-gated)
- Session restore + background cache refresh against the server
- Edit display name / profile photo
- Change password (current-password check)
- Delete account (soft delete: scrubs PII, preserves shared expense/settlement history for other members)

**Groups**
- Create, join by invite code, list with per-group net balance
- Swipe-to-delete (creator only)
- Member list with real profile photos
- Invite via shareable code, or by phone number with an automatic WhatsApp click-to-chat invite + branded web preview page for people who haven't installed the app yet

**Expenses**
- Add expense with EQUAL, CUSTOM (uneven naira amounts), or PERCENTAGE splits — all validated server-side
- Five expense templates (generic, owambe, ajo/esusu, shared subscription, rent)
- Expense history per group, newest first
- Expense detail view with per-person split breakdown and profile photos
- Delete an expense (payer/creator only)

**Balances & settlements**
- Debt-simplification algorithm (fewest transactions to settle a group, not one per expense)
- Balances/settlements scoped to only what actually involves the viewer
- Payout account setup (bank + account number, resolved to a real name via Paystack) — required before receiving money
- Real Paystack transfer on "pay," confirmed only via a signature-verified webhook (never client-side optimism)
- Manual reconcile action for a stuck PENDING settlement

**Activity & Wallet**
- Cross-group activity feed, correctly scoped to the viewer
- Wallet tab with settlement history
- Tappable list items everywhere, consistent with the rest of the app

**Design/UX polish**
- Full custom brand UI kit (theme, buttons, text fields, sheets, dialogs)
- Bouncing-dots loading animation everywhere (replacing the default spinner)
- Sliding-pill split-mode toggle, redesigned settlement confirmation sheet, redesigned destructive-action dialogs

## What we haven't done yet

- **ITEMIZED split type** — the backend fully supports it (assign individual line items to specific people), but there's no mobile UI for it. EQUAL/CUSTOM/PERCENTAGE are the only ones reachable from the app.
- **Recurring expenses** — the database has the fields for it (`isRecurring`, `recurrenceFreq`, a link back to a parent expense) but nothing actually generates recurring instances, and there's no UI. This was explicitly deferred earlier in the build.
- **Automatic settlement reconciliation** — right now a stuck PENDING settlement only gets unstuck if someone manually taps reconcile. No scheduled job sweeps for these on its own.
- **Route-level/integration tests** — the test suite covers the money-correctness logic (split calculation, debt simplification, webhook signature verification) but not the actual API routes end to end.
- **Push notifications** — nothing exists for "someone added an expense" or "you got paid" style alerts; you'd only see it next time you open the app.
- **Photo storage** — profile and expense photos are stored as base64 text directly in Postgres (no object storage/CDN). Fine at current scale, but worth revisiting if photo volume grows.
- **Email OTP** — you've decided to leave this for now and stick with mobile/SMS OTP, so no action needed here.

## Not pushed yet

The mobile frontend is committed locally (commit `Add SplitNaija Flutter frontend`) but not yet pushed to GitHub — this sandbox has no GitHub credentials. Run `git push origin main` from your own machine to finish that.
