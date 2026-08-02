import axios from "axios";
import crypto from "crypto";

const PAYSTACK_SECRET = process.env.PAYSTACK_SECRET_KEY || "";
const BASE_URL = "https://api.paystack.co";

const client = axios.create({
  baseURL: BASE_URL,
  headers: { Authorization: `Bearer ${PAYSTACK_SECRET}` },
});

/**
 * Initiates a transfer for a settlement. Requires a recipient already
 * created via createTransferRecipient() below — a payee can't receive a
 * transfer without one on file.
 */
export async function initiateTransfer(params: {
  amountKobo: number;
  recipientCode: string;
  reference: string;
  reason: string;
}) {
  const { data } = await client.post("/transfer", {
    source: "balance",
    amount: params.amountKobo,
    recipient: params.recipientCode,
    reference: params.reference,
    reason: params.reason,
  });
  return data;
}

/**
 * Resolves a bank account to its account name, so a recipient isn't created
 * against a typo'd account number without the user noticing.
 */
export async function resolveBankAccount(params: { accountNumber: string; bankCode: string }) {
  const { data } = await client.get("/bank/resolve", {
    params: { account_number: params.accountNumber, bank_code: params.bankCode },
  });
  return data.data as { account_number: string; account_name: string; bank_id: number };
}

/**
 * Creates a Paystack transfer recipient for a payee's bank account. Must
 * happen before that user can *receive* a settlement (PRD §8 / build brief §4).
 */
export async function createTransferRecipient(params: {
  accountNumber: string;
  bankCode: string;
  accountName: string;
}) {
  const { data } = await client.post("/transferrecipient", {
    type: "nuban",
    name: params.accountName,
    account_number: params.accountNumber,
    bank_code: params.bankCode,
    currency: "NGN",
  });
  return data.data as { recipient_code: string };
}

/**
 * Looks up a transfer's current status by reference — used by the manual
 * reconciliation endpoint to unstick a settlement that never got a webhook.
 */
export async function getTransferStatus(reference: string) {
  const { data } = await client.get(`/transfer/verify/${reference}`);
  return data.data as { status: string };
}

/**
 * Validates that a webhook payload really came from Paystack.
 * PRD §8 non-functional requirement: balance must never flip to
 * "settled" without a confirmed, verified payment event. Uses a
 * constant-time comparison to avoid leaking signature bytes via timing.
 */
export function verifyWebhookSignature(rawBody: Buffer | string, signatureHeader: string): boolean {
  const expected = crypto.createHmac("sha512", PAYSTACK_SECRET).update(rawBody).digest("hex");

  const expectedBuf = Buffer.from(expected, "utf8");
  const actualBuf = Buffer.from(signatureHeader, "utf8");
  if (expectedBuf.length !== actualBuf.length) return false;

  return crypto.timingSafeEqual(expectedBuf, actualBuf);
}
