# SplitNaija — Backend

Monorepo for the MVP described in the PRD: `/backend` (API) and `/mobile` (Flutter app, scaffold only — not actively developed here).

## Architecture

```
mobile (Flutter)  --HTTPS-->  backend (Express/TS)  --SQL-->  PostgreSQL
                                    |
                                    +--> Termii (OTP SMS delivery)
                                    +--> Paystack (transfer recipients, settlement transfers + webhook)
```

- **backend/src/services/debtSimplification.ts** — the core "who pays whom" algorithm. Greedy netting: nets every expense split, payment, and CONFIRMED settlement against each other, then matches largest debtor to largest creditor until balances zero out.
- **backend/src/services/splitCalculator.ts** — turns an expense + split method (equal/percentage/custom/itemized) into per-member kobo shares, with remainder kobo always fully and exactly distributed.
- **backend/src/services/otp.ts** — generates, hashes, stores (DB-backed, short TTL), and verifies phone OTP codes; delivers via Termii.
- **backend/src/services/paystack.ts** — webhook signature verification (HMAC-SHA512, constant-time compare), transfer recipient creation, bank account resolution, transfer initiation, transfer status lookup.
- **backend/prisma/schema.prisma** — the data model: User (+ Paystack payout fields), Group, GroupMember (supports non-registered phone-only members for the WhatsApp flow), Expense, ExpenseSplit, Settlement, OtpCode.
- **backend/src/routes/** — one file per resource (auth, groups, expenses, balances, settlements). Settlement webhook only ever confirms a payment off a verified, raw-body-HMAC-checked Paystack signature, and is idempotent against duplicate deliveries — never optimistically from the client.
- **mobile/lib/** — Flutter app skeleton (not part of this build's scope; left as-is).

Money is stored and passed as integer kobo everywhere (never floats) to avoid rounding drift.

## Local setup

```bash
docker compose up -d          # starts Postgres on :5432
cd backend
npm install
cp .env.example .env          # fill in JWT_SECRET, PAYSTACK_SECRET_KEY, TERMII_API_KEY
npx prisma migrate dev        # applies the schema to a fresh database
npm run dev                   # http://localhost:4000
```

Without a `TERMII_API_KEY` set, OTP codes are logged to the console instead of sent via SMS — useful for local dev without a Termii account.

### Tests

```bash
npm test
```

Covers `computeNetBalances()` / `simplifyDebts()` (2-person, multi-person chains, zero-sum groups, odd-kobo remainders, CONFIRMED-settlement netting), `calculateSplits()` for all four split types including rejection paths, and Paystack webhook signature verification (valid/tampered/wrong-secret).

## API surface

| Route | Auth | Notes |
|---|---|---|
| `POST /auth/otp/request` | – | sends OTP via Termii |
| `POST /auth/otp/verify` | – | verifies OTP, upserts user, returns JWT (30d) |
| `POST /groups` | ✓ | creates group, adds creator as first member |
| `GET /groups` | ✓ | lists the caller's groups |
| `GET /groups/preview/:inviteCode` | – | public web-view preview |
| `POST /groups/join` | ✓ | joins by invite code |
| `GET /groups/:groupId/members` | ✓ | group member picker |
| `POST /groups/:groupId/members/invite` | ✓ | adds a phone-only (non-registered) member |
| `POST /expenses` | ✓ | server-side split calculation, never trusts client shares |
| `GET /expenses/group/:groupId` | ✓ | newest first, with splits |
| `GET /balances/group/:groupId` | ✓ | net balances + simplified settle-up transactions |
| `POST /settlements/recipients` | ✓ | resolves bank account, creates Paystack transfer recipient |
| `POST /settlements` | ✓ | creates PENDING settlement, initiates Paystack transfer |
| `POST /settlements/webhook/paystack` | HMAC | idempotent, signature-verified transfer confirmation |
| `POST /settlements/:id/reconcile` | ✓ | manual override: re-queries Paystack for a stuck PENDING settlement |

## Known gaps / TODOs

- Reconciliation is manual-trigger only (`POST /settlements/:id/reconcile`); no scheduled job yet sweeping stale PENDING settlements automatically.
- No integration/route-level tests — unit coverage on the money-correctness logic (splits, netting, webhook auth) was prioritized per the brief.
- WhatsApp delivery of the invite link for phone-only members is Phase 2, not implemented.
