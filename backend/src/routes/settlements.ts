import { Router } from "express";
import { z } from "zod";
import { randomUUID } from "crypto";
import { prisma } from "../lib/prisma";
import { requireAuth, AuthedRequest } from "../middleware/auth";
import {
  verifyWebhookSignature,
  initiateTransfer,
  resolveBankAccount,
  createTransferRecipient,
  getTransferStatus,
} from "../services/paystack";
import { sendPushToUser } from "../services/push";

export const settlementsRouter = Router();

const SETTLEMENT_FEE_BPS = 150; // 1.5% — tune against PRD §15 open question on fee level

// TEMPORARY: real Paystack transfers require a Registered Business (see the
// "starter business" error this was added to work around) — until that
// verification goes through, this flag skips the real Paystack transfer call
// entirely and marks the settlement CONFIRMED immediately, so the rest of
// the app (activity feed, wallet history, balances zeroing out, push
// notifications) can be built and tested end-to-end without real money
// moving. No real transfer ever happens while this is on — nothing to
// reconcile, no webhook involved, nothing hits Paystack's transfer API at
// all for this request.
//
// MUST be unset (or "false") before this app is ever used with real money.
// It stays behind an explicit env var — never inferred from NODE_ENV or the
// Paystack key type — specifically so turning real transfers back on is a
// deliberate action, not an accident of deploying to a different
// environment.
const SIMULATE_TRANSFERS = process.env.PAYSTACK_SIMULATE_TRANSFERS === "true";

// Every settlement the caller is on either side of (sent or received),
// across all their groups — powers the Wallet tab's history list. Select
// only the fields each nested user needs so this never risks leaking
// `passwordHash` the way the old `payer: true` include did on expenses
// (see src/lib/user.ts and the fix in routes/expenses.ts).
settlementsRouter.get("/", requireAuth, async (req: AuthedRequest, res) => {
  const settlements = await prisma.settlement.findMany({
    where: { OR: [{ fromUserId: req.userId! }, { toUserId: req.userId! }] },
    orderBy: { createdAt: "desc" },
    include: {
      group: { select: { id: true, name: true } },
      from: { select: { id: true, displayName: true } },
      to: { select: { id: true, displayName: true } },
    },
  });

  res.json(settlements);
});

// A payee needs a Paystack transfer recipient on file (bank account, not
// just a phone number) before they can *receive* a settlement.
const createRecipientSchema = z.object({
  bankCode: z.string().min(1),
  accountNumber: z.string().min(1),
});

settlementsRouter.post("/recipients", requireAuth, async (req: AuthedRequest, res) => {
  const parsed = createRecipientSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);
  const { bankCode, accountNumber } = parsed.data;

  let resolved;
  try {
    resolved = await resolveBankAccount({ accountNumber, bankCode });
  } catch (err) {
    // Logged with Paystack's actual response body — a bare catch here used
    // to hide whether this was a bad account number, a wrong/expired key,
    // or a network problem, all behind the same generic client-facing
    // message. The client-facing message stays generic on purpose (don't
    // leak API internals), but now there's something to actually debug from.
    console.error("resolveBankAccount failed:", (err as { response?: { data?: unknown } })?.response?.data ?? err);
    return res.status(400).json({ error: "Could not resolve bank account details" });
  }

  let recipient;
  try {
    recipient = await createTransferRecipient({
      accountNumber,
      bankCode,
      accountName: resolved.account_name,
    });
  } catch (err) {
    console.error("createTransferRecipient failed:", (err as { response?: { data?: unknown } })?.response?.data ?? err);
    return res.status(502).json({ error: "Failed to create Paystack transfer recipient" });
  }

  const user = await prisma.user.update({
    where: { id: req.userId! },
    data: {
      bankCode,
      accountNumber,
      accountName: resolved.account_name,
      paystackRecipientCode: recipient.recipient_code,
    },
  });

  res.status(201).json({
    bankCode: user.bankCode,
    accountNumber: user.accountNumber,
    accountName: user.accountName,
    paystackRecipientCode: user.paystackRecipientCode,
  });
});

const initiateSchema = z.object({
  groupId: z.string(),
  toUserId: z.string(),
  amountKobo: z.number().int().positive(),
});

settlementsRouter.post("/", requireAuth, async (req: AuthedRequest, res) => {
  const parsed = initiateSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);
  const data = parsed.data;

  const group = await prisma.group.findUnique({ where: { id: data.groupId } });
  if (!group) return res.status(404).json({ error: "Group not found" });

  const toUser = await prisma.user.findUnique({ where: { id: data.toUserId } });
  if (!toUser?.paystackRecipientCode) {
    return res.status(400).json({ error: "Recipient has not set up a payout account yet" });
  }

  const feeKobo = Math.round((data.amountKobo * SETTLEMENT_FEE_BPS) / 10000);

  const settlement = await prisma.settlement.create({
    data: {
      groupId: data.groupId,
      fromUserId: req.userId!,
      toUserId: data.toUserId,
      amountKobo: data.amountKobo,
      feeKobo,
      status: "PENDING",
      paystackRef: randomUUID(),
    },
  });

  if (SIMULATE_TRANSFERS) {
    console.warn(
      `[settlements] SIMULATING transfer for settlement ${settlement.id} — no real Paystack transfer was made. ` +
        `Set PAYSTACK_SIMULATE_TRANSFERS=false once your business is verified.`
    );
    const confirmed = await prisma.settlement.update({
      where: { id: settlement.id },
      data: { status: "CONFIRMED", confirmedAt: new Date() },
    });
    const payer = await prisma.user.findUnique({ where: { id: req.userId! }, select: { displayName: true } });
    void sendPushToUser(data.toUserId, {
      title: "Payment received",
      body: `${payer?.displayName ?? "Someone"} paid you in ${group.name}.`,
      data: { type: "settlement_confirmed", groupId: data.groupId, settlementId: settlement.id },
    });
    return res.status(201).json(confirmed);
  }

  try {
    await initiateTransfer({
      amountKobo: data.amountKobo,
      recipientCode: toUser.paystackRecipientCode,
      reference: settlement.paystackRef!,
      reason: `SplitNaija settlement — group ${data.groupId}`,
    });
  } catch (err) {
    // Same bare-catch mistake as resolveBankAccount/createTransferRecipient
    // originally had — this was swallowing the real Paystack error (e.g.
    // insufficient test balance, transfers not enabled, OTP required)
    // behind a generic message with nothing to debug from. Logging the
    // actual response body now; client-facing message stays generic.
    console.error("initiateTransfer failed:", (err as { response?: { data?: unknown } })?.response?.data ?? err);
    // The transfer never left the ground — fail fast rather than leaving
    // this PENDING forever waiting on a webhook that will never arrive.
    await prisma.settlement.update({ where: { id: settlement.id }, data: { status: "FAILED" } });
    // The payer is already staring at an error in the app right now (this
    // request is synchronous from their tap), so this push is mostly for
    // when they've since backgrounded the app or it's on another device.
    void sendPushToUser(req.userId!, {
      title: "Payment failed",
      body: `Your payment to ${toUser.displayName} in ${group.name} didn't go through.`,
      data: { type: "settlement_failed", groupId: data.groupId, settlementId: settlement.id },
    });
    return res.status(502).json({ error: "Failed to initiate transfer", settlement });
  }

  res.status(201).json(settlement);
});

// Paystack calls this when a transfer succeeds or fails. Per PRD §8, a
// settlement must only ever flip to CONFIRMED off a verified webhook —
// never optimistically from the client.
//
// req.body here is the raw request Buffer, not parsed JSON — see index.ts,
// which registers express.raw() for this exact path ahead of the global
// express.json(), because the HMAC must be computed over the exact bytes
// Paystack signed (JSON.stringify(parsedBody) is not guaranteed to match).
settlementsRouter.post("/webhook/paystack", async (req, res) => {
  const signature = req.headers["x-paystack-signature"];
  const rawBody = req.body as Buffer;

  if (!signature || typeof signature !== "string" || !verifyWebhookSignature(rawBody, signature)) {
    return res.status(401).json({ error: "Invalid signature" });
  }

  const event = JSON.parse(rawBody.toString("utf8"));
  const reference = event?.data?.reference;
  if (!reference) return res.status(400).json({ error: "Missing reference" });

  const settlement = await prisma.settlement.findUnique({
    where: { paystackRef: reference },
    include: {
      group: { select: { name: true } },
      from: { select: { displayName: true } },
      to: { select: { displayName: true } },
    },
  });
  if (!settlement) return res.status(404).json({ error: "Settlement not found" });

  // Guard the transition on status: "PENDING" so a duplicate webhook
  // delivery (Paystack retries on anything but a 200) is a no-op instead
  // of re-processing an already-settled transaction. The push only fires
  // when this call is the one that actually made the transition (count > 0)
  // — otherwise a retried webhook would notify someone twice for one payment.
  if (event.event === "transfer.success") {
    const { count } = await prisma.settlement.updateMany({
      where: { id: settlement.id, status: "PENDING" },
      data: { status: "CONFIRMED", confirmedAt: new Date() },
    });
    if (count > 0) {
      void sendPushToUser(settlement.toUserId, {
        title: "Payment received",
        body: `${settlement.from.displayName} paid you in ${settlement.group.name}.`,
        data: { type: "settlement_confirmed", groupId: settlement.groupId, settlementId: settlement.id },
      });
    }
  } else if (event.event === "transfer.failed" || event.event === "transfer.reversed") {
    const { count } = await prisma.settlement.updateMany({
      where: { id: settlement.id, status: "PENDING" },
      data: { status: "FAILED" },
    });
    if (count > 0) {
      void sendPushToUser(settlement.fromUserId, {
        title: "Payment failed",
        body: `Your payment to ${settlement.to.displayName} in ${settlement.group.name} didn't go through.`,
        data: { type: "settlement_failed", groupId: settlement.groupId, settlementId: settlement.id },
      });
    }
  }

  res.sendStatus(200);
});

// Manual reconciliation: unsticks a settlement that never got a webhook
// delivery by asking Paystack for the transfer's current status directly.
// TODO: also run this on a schedule (e.g. hourly cron over PENDING
// settlements older than N minutes) so it doesn't require someone to
// notice and call it by hand.
settlementsRouter.post("/:id/reconcile", requireAuth, async (req, res) => {
  const settlement = await prisma.settlement.findUnique({
    where: { id: req.params.id },
    include: {
      group: { select: { name: true } },
      from: { select: { displayName: true } },
      to: { select: { displayName: true } },
    },
  });
  if (!settlement) return res.status(404).json({ error: "Settlement not found" });
  if (settlement.status !== "PENDING" || !settlement.paystackRef) {
    return res.json(settlement);
  }

  let status: string;
  try {
    const result = await getTransferStatus(settlement.paystackRef);
    status = result.status;
  } catch {
    return res.status(502).json({ error: "Failed to query Paystack transfer status" });
  }

  if (status === "success") {
    const { count } = await prisma.settlement.updateMany({
      where: { id: settlement.id, status: "PENDING" },
      data: { status: "CONFIRMED", confirmedAt: new Date() },
    });
    if (count > 0) {
      void sendPushToUser(settlement.toUserId, {
        title: "Payment received",
        body: `${settlement.from.displayName} paid you in ${settlement.group.name}.`,
        data: { type: "settlement_confirmed", groupId: settlement.groupId, settlementId: settlement.id },
      });
    }
  } else if (status === "failed" || status === "reversed") {
    const { count } = await prisma.settlement.updateMany({
      where: { id: settlement.id, status: "PENDING" },
      data: { status: "FAILED" },
    });
    if (count > 0) {
      void sendPushToUser(settlement.fromUserId, {
        title: "Payment failed",
        body: `Your payment to ${settlement.to.displayName} in ${settlement.group.name} didn't go through.`,
        data: { type: "settlement_failed", groupId: settlement.groupId, settlementId: settlement.id },
      });
    }
  }

  const updated = await prisma.settlement.findUnique({ where: { id: settlement.id } });
  res.json(updated);
});
