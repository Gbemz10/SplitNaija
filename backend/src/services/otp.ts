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
// Termii now assigns each account its own base URL (shown on your Termii
// dashboard) rather than one shared hostname for everyone — the old
// hardcoded api.ns.termii.com was from before that change and just resets
// the connection now. Confirmed from the actual dashboard: v4.api.termii.com.
const TERMII_BASE_URL = process.env.TERMII_BASE_URL || "https://v4.api.termii.com/api";

const OTP_TTL_MINUTES = 10;
const OTP_MAX_ATTEMPTS = 5;

// TEMPORARY: Termii's Sender ID approval (needed before any real SMS can
// send under "SplitNaija") requires business documents that aren't ready
// yet. Until that clears, this skips the real Termii call entirely and
// accepts ANY code as valid — signup/login/password-reset all work without
// a real SMS ever going out, so people can actually get through onboarding
// in the APK.
//
// This is a real security bypass, not a cosmetic shortcut: with this on,
// phone number ownership is never actually verified, so anyone can sign up
// claiming to be any number. MUST be unset (or "false") before this app is
// ever used with real users' real phone numbers. Same pattern as
// PAYSTACK_SIMULATE_TRANSFERS — a deliberate, explicit env var, never
// inferred from NODE_ENV or whether a Termii key happens to be set.
const OTP_BYPASS_VERIFICATION = process.env.OTP_BYPASS_VERIFICATION === "true";

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

  if (OTP_BYPASS_VERIFICATION) {
    console.warn(
      `[otp] BYPASS ACTIVE — not sending a real SMS to ${phoneNumber}. Any code will be accepted for this number right now. ` +
        `Set OTP_BYPASS_VERIFICATION=false once Sender ID approval clears.`
    );
    return;
  }

  // Matches Termii's own recommended OTP template (the "don't share" line
  // is their suggested format, not just decoration) — keeping the real
  // message in sync with what was submitted for Sender ID approval avoids
  // a mismatch between what got approved and what actually gets sent.
  await sendSms(
    phoneNumber,
    `Your SplitNaija verification code is ${code}. This code expires in ${OTP_TTL_MINUTES} minutes. Do not share with anyone.`
  );
}

export async function verifyOtp(phoneNumber: string, code: string): Promise<boolean> {
  if (OTP_BYPASS_VERIFICATION) return true;

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

/**
 * Same check as verifyOtp but doesn't consume the code — lets the client
 * give immediate "wrong code" feedback on the OTP-entry screen itself
 * (rather than silently letting any 6 digits through the rest of a signup
 * or password-reset wizard), while the *real*, consuming check still
 * happens once, at the end, in verifyOtp. A wrong guess here still counts
 * against OTP_MAX_ATTEMPTS so this can't be used to brute-force the code.
 */
export async function checkOtp(phoneNumber: string, code: string): Promise<boolean> {
  if (OTP_BYPASS_VERIFICATION) return true;

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

  return true;
}
