/**
 * Password hashing for phone+password auth.
 *
 * Uses Node's built-in `crypto.scrypt` (a memory-hard KDF, Node's own docs
 * recommend it for password storage) rather than pulling in bcrypt — keeps
 * this dependency-free, consistent with how OTP codes are already hashed
 * with the built-in `crypto` module in services/otp.ts.
 *
 * Stored format: "<saltHex>:<derivedKeyHex>".
 */
import crypto from "crypto";

const KEY_LENGTH = 64;

export function hashPassword(password: string): string {
  const salt = crypto.randomBytes(16).toString("hex");
  const derivedKey = crypto.scryptSync(password, salt, KEY_LENGTH);
  return `${salt}:${derivedKey.toString("hex")}`;
}

export function verifyPassword(password: string, stored: string): boolean {
  const [salt, hashHex] = stored.split(":");
  if (!salt || !hashHex) return false;

  const derivedKey = crypto.scryptSync(password, salt, KEY_LENGTH);
  const storedBuf = Buffer.from(hashHex, "hex");
  if (storedBuf.length !== derivedKey.length) return false;

  return crypto.timingSafeEqual(storedBuf, derivedKey);
}
