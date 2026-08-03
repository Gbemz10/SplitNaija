# SplitNaija Mobile — Frontend Build Brief

## Context

This is the Flutter frontend for SplitNaija, a Nigeria-focused group expense-splitting app (Splitwise-style, with in-app naira settlement via Paystack). The backend is fully built, tested, and running — Node/TypeScript/Express/Prisma/PostgreSQL, source at `https://github.com/Gbemz10/SplitNaija` (backend/ folder), README there has the full API reference. This brief is self-contained though — you shouldn't need to go read backend source to get started.

**Stack (already set up, don't change):** Flutter, `provider` for state/DI, `http` for networking, `flutter_secure_storage` for the session token, `intl`.

**Non-negotiable convention:** the backend does all money in integer **kobo** (never naira floats). The frontend receives/sends kobo everywhere over the API. Only convert to naira for display, using the existing `formatKobo()` helper in `lib/models/models.dart`. When collecting a naira amount from a text field, convert with `(nairaValue * 100).round()` before sending.

## Current state of the scaffold — read this before writing anything

Everything below already exists in `mobile/lib/`. Some of it is real and working, some is a stub that looks finished but isn't. Don't rebuild what's already correct.

**Working / real:**
- `main.dart` — app bootstrap, provider wiring, session-restore gate (checks secure storage on launch, routes to `GroupsScreen` or `LoginScreen`). Fine as-is.
- `services/api_client.dart` — thin REST wrapper (`get`/`post`/`getList`), bearer token injection, `ApiException`. Fine as-is.
- `services/auth_service.dart` — OTP request/verify, token persisted via `flutter_secure_storage`. Functionally correct.
- `login_screen.dart` — phone → OTP → verify flow. UI works.
- `models/models.dart` — `Group`, `Expense`, `ExpenseSplit`, `SuggestedSettlement`, `formatKobo()`.

**Broken or stubbed — this is the actual work:**

1. **`GroupService.listMyGroups()` returns a hardcoded empty list.** The comment says it's waiting on `GET /groups` — that endpoint now exists and works (`GET /groups`, auth required, returns the array of groups the caller belongs to). Wire it up. This is why `GroupsScreen` currently always shows "No groups yet" even after creating one.

2. **`AddExpenseScreen` is actually broken against the real backend right now.** It calls `addExpense(..., participantIds: [])` — hardcoded empty. The backend's split calculator throws `"EQUAL split needs at least one participant"` on an empty list, so submitting any expense currently fails outright. You need:
   - A `GroupMember` model (doesn't exist yet in `models.dart`) matching `GET /groups/:groupId/members` response shape: `{ id, groupId, userId, phoneNumber, displayName, joinedAt, isRegistered }`.
   - A `getGroupMembers(groupId)` method on `GroupService` hitting that endpoint.
   - A real participant picker UI in `AddExpenseScreen` (checkboxes/chips against the group's member list) that feeds real `participantIds`.

3. **No way to know "who am I."** `AuthService.verifyOtp()` gets back `{ token, user }` from the backend but discards `user` — only the token is persisted. You have no current-user id/displayName anywhere in the app. This matters for: showing "you paid" vs "they paid" on expenses, excluding yourself from some UI, etc. Add a `User` model, persist it (secure storage or just in-memory via a provider since session restore already re-hits stored token — decide based on whether you want it available before an API round-trip), and expose it via `AuthService` or a small `CurrentUserProvider`.

4. **`GroupDetailScreen` never shows expense history.** `GroupService.listExpenses()` already exists and works (`GET /expenses/group/:groupId`) but nothing calls it. The screen only shows suggested settlements. Add an expense list section — most recent first (the API already returns them that way), showing description, amount (via `formatKobo`), payer, and date.

5. **`GroupDetailScreen` shows raw user IDs, not names.** `'${s.fromUserId} → ${s.toUserId}'` — need to resolve those against the member list (from #2) to show display names instead of UUIDs.

6. **Tapping a suggested settlement does nothing.** There's a bare `// TODO` comment where `onTap` should call `POST /settlements` with `{ groupId, toUserId, amountKobo }`. Before that will succeed, though — see #7.

7. **No Paystack recipient setup screen at all.** Per the backend: a user cannot *receive* a settlement until they've called `POST /settlements/recipients` with `{ bankCode, accountNumber }` (backend resolves the account name via Paystack and stores it). Without this screen, #6 will always fail with "Recipient has not set up a payout account yet." Needs: a bank + account number form, ideally a bank picker (Paystack has a `GET /bank` list endpoint you can proxy through the backend later, or hardcode a common Nigerian bank list for now), submit, show confirmation with the resolved account name.

8. **`AddExpenseScreen` only supports EQUAL split.** Backend supports EQUAL/PERCENTAGE/CUSTOM/ITEMIZED. EQUAL-only is a fine v1 — just know the other three are display-only gaps, not bugs, if you triage.

9. **No invite/share flow.** No screen surfaces `group.inviteCode`, no share sheet, no UI for `POST /groups/:groupId/members/invite` (add a non-app-user by phone — the WhatsApp flow), no use of the public `GET /groups/preview/:inviteCode` (which is what a web-view link would hit before someone's installed the app).

10. **`login_screen.dart` hardcodes `displayName: 'New User'`** on OTP verify — there's no actual name-collection field for first-time signup. Should conditionally show a name field when the OTP-verify call indicates a new user (or just always ask for it before requesting OTP — your call).

11. **`ApiClient` baseUrl defaults to `http://10.0.2.2:4000`** — that's the Android-emulator-only alias for the host machine. If you're running on the iOS Simulator, this needs to be `http://localhost:4000` instead. On a physical device (either platform), it needs your Mac's LAN IP. Don't hardcode one value — make it configurable (e.g. `--dart-define`, a debug settings screen, or platform detection) since you'll likely switch between iOS Simulator and Android emulator while developing.

## Backend API reference (self-contained)

Base URL: your running backend (`docker compose up -d` + `npm run dev` in `backend/`, port 4000). Auth: `Authorization: Bearer <token>` header, obtained from `/auth/otp/verify`.

| Method & path | Auth | Body | Response |
|---|---|---|---|
| `POST /auth/otp/request` | – | `{ phoneNumber }` | `{ message }` |
| `POST /auth/otp/verify` | – | `{ phoneNumber, code, displayName? }` | `{ token, user }` |
| `POST /groups` | ✓ | `{ name }` | created `Group` incl. `members[]`, `inviteCode` |
| `GET /groups` | ✓ | – | `Group[]` (caller's groups) |
| `GET /groups/preview/:inviteCode` | – | – | `{ id, name, memberCount }` |
| `POST /groups/join` | ✓ | `{ inviteCode }` | `GroupMember` |
| `GET /groups/:groupId/members` | ✓ | – | `GroupMember[]` |
| `POST /groups/:groupId/members/invite` | ✓ | `{ phoneNumber, displayName }` | created `GroupMember` (`isRegistered: false`) |
| `POST /expenses` | ✓ | `{ groupId, description, amountKobo, template?, category?, note?, photoUrl?, split }` | created `Expense` incl. `splits[]` |
| `GET /expenses/group/:groupId` | ✓ | – | `Expense[]`, newest first, incl. `splits[]` and `payer` |
| `GET /balances/group/:groupId` | ✓ | – | `{ netBalances[], suggestedSettlements[] }` |
| `POST /settlements/recipients` | ✓ | `{ bankCode, accountNumber }` | `{ bankCode, accountNumber, accountName, paystackRecipientCode }` |
| `POST /settlements` | ✓ | `{ groupId, toUserId, amountKobo }` | created `Settlement` (status `PENDING`) |
| `POST /settlements/:id/reconcile` | ✓ | – | current `Settlement` state |

`split` shapes for `POST /expenses`:
```json
{ "type": "EQUAL", "participantIds": ["userId1", "userId2"] }
{ "type": "PERCENTAGE", "shares": [{ "userId": "u1", "percentage": 60 }, { "userId": "u2", "percentage": 40 }] }
{ "type": "CUSTOM", "shares": [{ "userId": "u1", "amountKobo": 60000 }, { "userId": "u2", "amountKobo": 40000 }] }
{ "type": "ITEMIZED", "items": [{ "amountKobo": 50000, "assignedTo": ["u1", "u2"] }] }
```

`template` enum: `GENERIC | OWAMBE_CONTRIBUTION | AJO_ESUSU_ROUND | SHARED_SUBSCRIPTION | RENT` (already wired up correctly in `AddExpenseScreen`).

Every error response is `{ error: "message" }` with a 4xx/5xx status — `ApiException` in `api_client.dart` already surfaces `statusCode` and `body` for this.

## Suggested build order

1. Fix `listMyGroups()` → wire to `GET /groups`. Unblocks the groups list, which is currently dead.
2. Add `GroupMember` model + `getGroupMembers()`. This unblocks both the participant picker (#2 below) and name resolution in the settlements list.
3. Fix `AddExpenseScreen`'s participant picker — this is the actual currently-broken core flow, prioritize it over everything else.
4. Add current-user tracking (`User` model, persist from `verifyOtp`).
5. Add expense history list to `GroupDetailScreen`.
6. Resolve names instead of raw IDs in the settlements list.
7. Wire the settlement `onTap` → `POST /settlements`, with a clear error state when the recipient hasn't set up payouts yet (pointing at #8).
8. Build the Paystack recipient setup screen.
9. Build invite/share UI (invite code display + share sheet + phone-invite form).
10. First-signup name collection.
11. (Stretch) PERCENTAGE/CUSTOM/ITEMIZED split UI.

## Design notes

- Existing theme uses `Color(0xFF00A651)` (Nigerian green) as the seed color via Material 3 — keep that.
- Keep using `formatKobo()` for all money display — don't hand-roll naira formatting elsewhere.
- The four expense templates map to real Nigerian group-expense patterns (owambe/aso-ebi contributions, ajo/esusu rounds, shared subscriptions, rent) — worth reflecting in icons/copy if you touch that screen, not just a generic dropdown.
