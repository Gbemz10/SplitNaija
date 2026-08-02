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

export const settlementsRouter = Router();

const SETTLEMENT_FEE_BPS = 150; // 1.5% — tune against PRD §15 open question on fee level

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
  } catch {
    return res.status(400).json({ error: "Could not resolve bank account details" });
  }

  let recipient;
  try {
    recipient = await createTransferRecipient({
      accountNumber,
      bankCode,
      accountName: resolved.account_name,
    });
  } catch {
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

  try {
    await initiateTransfer({
      amountKobo: data.amountKobo,
      recipientCode: toUser.paystackRecipientCode,
      reference: settlement.paystackRef!,
      reason: `SplitNaija settlement — group ${data.groupId}`,
    });
  } catch {
    // The transfer never left the ground — fail fast rather than leaving
    // this PENDING forever waiting on a webhook that will never arrive.
    await prisma.settlement.update({ where: { id: settlement.id }, data: { status: "FAILED" } });
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

  const settlement = await prisma.settlement.findUnique({ where: { paystackRef: reference } });
  if (!settlement) return res.status(404).json({ error: "Settlement not found" });

  // Guard the transition on status: "PENDING" so a duplicate webhook
  // delivery (Paystack retries on anything but a 200) is a no-op instead
  // of re-processing an already-settled transaction.
  if (event.event === "transfer.success") {
    await prisma.settlement.updateMany({
      where: { id: settlement.id, status: "PENDING" },
      data: { status: "CONFIRMED", confirmedAt: new Date() },
    });
  } else if (event.event === "transfer.failed" || event.event === "transfer.reversed") {
    await prisma.settlement.updateMany({
      where: { id: settlement.id, status: "PENDING" },
      data: { status: "FAILED" },
    });
  }

  res.sendStatus(200);
});

// Manual reconciliation: unsticks a settlement that never got a webhook
// delivery by asking Paystack for the transfer's current status directly.
// TODO: also run this on a schedule (e.g. hourly cron over PENDING
// settlements older than N minutes) so it doesn't require someone to
// notice and call it by hand.
settlementsRouter.post("/:id/reconcile", requireAuth, async (req, res) => {
  const settlement = await prisma.settlement.findUnique({ where: { id: req.params.id } });
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
    await prisma.settlement.updateMany({
      where: { id: settlement.id, status: "PENDING" },
      data: { status: "CONFIRMED", confirmedAt: new Date() },
    });
  } else if (status === "failed" || status === "reversed") {
    await prisma.settlement.updateMany({
      where: { id: settlement.id, status: "PENDING" },
      data: { status: "FAILED" },
    });
  }

  const updated = await prisma.settlement.findUnique({ where: { id: settlement.id } });
  res.json(updated);
});
