/**
 * Phone-number OTP: generate, deliver via Termii, verify.
 *
 * SMS provider: Termii (chosen over Africa's Talking for solid Nigeria
 * network coverage and a simple REST send API — either would satisfy the
 * brief, this is just the pick).
 *
 * Codes are stored hashed with a short TTL in the OtpCode table (DB-backed
 * per the brief's "Redis if available, otherwise a DB table" — no Redis in
 * this environment, so a table with an expiry column it is).
 */
import crypto from "crypto";
import axios from "axios";
import { prisma } from "../lib/prisma";

const TERMII_API_KEY = process.env.TERMII_API_KEY || "";
const TERMII_SENDER_ID = process.env.TERMII_SENDER_ID || "SplitNaija";
const TERMII_BASE_URL = "https://api.ns.termii.com/api";

const OTP_TTL_MINUTES = 10;
const OTP_MAX_ATTEMPTS = 5;

function hashCode(code: string): string {
  return crypto.createHash("sha256").update(code).digest("hex");
}

async function sendSms(phoneNumber: string, message: string): Promise<void> {
  if (!TERMII_API_KEY) {
    // Dev fallback so local/testing flows aren't blocked on a real Termii
    // account — never throw, just log what would've been sent.
    console.log(`[otp] TERMII_API_KEY not set; would send to ${phoneNumber}: ${message}`);
    return;
  }

  await axios.post(`${TERMII_BASE_URL}/sms/send`, {
    api_key: TERMII_API_KEY,
    to: phoneNumber,
    from: TERMII_SENDER_ID,
    sms: message,
    type: "plain",
    channel: "generic",
  });
}

export async function requestOtp(phoneNumber: string): Promise<void> {
  const code = crypto.randomInt(100000, 1000000).toString();
  const expiresAt = new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000);

  await prisma.otpCode.create({
    data: { phoneNumber, codeHash: hashCode(code), expiresAt },
  });

  await sendSms(phoneNumber, `Your SplitNaija verification code is ${code}. It expires in ${OTP_TTL_MINUTES} minutes.`);
}

export async function verifyOtp(phoneNumber: string, code: string): Promise<boolean> {
  const candidate = await prisma.otpCode.findFirst({
    where: { phoneNumber, consumedAt: null, expiresAt: { gt: new Date() } },
    orderBy: { createdAt: "desc" },
  });

  if (!candidate || candidate.attempts >= OTP_MAX_ATTEMPTS) return false;

  if (candidate.codeHash !== hashCode(code)) {
    await prisma.otpCode.update({
      where: { id: candidate.id },
      data: { attempts: { increment: 1 } },
    });
    return false;
  }

  await prisma.otpCode.update({
    where: { id: candidate.id },
    data: { consumedAt: new Date() },
  });
  return true;
}
