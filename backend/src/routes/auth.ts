import { Router } from "express";
import { z } from "zod";
import { prisma } from "../lib/prisma";
import { toPublicUser } from "../lib/user";
import { AuthedRequest, issueToken, requireAuth } from "../middleware/auth";
import { checkOtp, requestOtp, verifyOtp } from "../services/otp";
import { hashPassword, verifyPassword } from "../services/password";

export const authRouter = Router();

const passwordSchema = z
  .string()
  .min(8, "Password must be at least 8 characters")
  .max(20, "Password must be at most 20 characters");

const requestOtpSchema = z.object({ phoneNumber: z.string().min(1) });

authRouter.post("/otp/request", async (req, res) => {
  const parsed = requestOtpSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);

  await requestOtp(parsed.data.phoneNumber);
  res.json({ message: "OTP sent" });
});

// Checks a code without consuming it — see checkOtp() for why this exists
// alongside /otp/verify. Used by the OTP-entry screen for immediate
// feedback; the actual signup/reset call still does the real, consuming
// check on this same code afterward.
const checkOtpSchema = z.object({
  phoneNumber: z.string().min(1),
  code: z.string().min(1),
});

authRouter.post("/otp/check", async (req, res) => {
  const parsed = checkOtpSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);

  const valid = await checkOtp(parsed.data.phoneNumber, parsed.data.code);
  res.json({ valid });
});

// Legacy OTP-only login/signup (no password). Superseded by /signup and
// /login below, kept around in case anything still points at it.
const verifyOtpSchema = z.object({
  phoneNumber: z.string().min(1),
  code: z.string().min(1),
  displayName: z.string().optional(), // required on first signup
});

authRouter.post("/otp/verify", async (req, res) => {
  const parsed = verifyOtpSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);
  const { phoneNumber, code, displayName } = parsed.data;

  const isValid = await verifyOtp(phoneNumber, code);
  if (!isValid) return res.status(401).json({ error: "Invalid or expired code" });

  const user = await prisma.user.upsert({
    where: { phoneNumber },
    update: {},
    create: { phoneNumber, displayName: displayName ?? "New User" },
  });

  const token = issueToken(user.id);
  res.json({ token, user: toPublicUser(user) });
});

// Signup: phone must already be OTP-verified in this same call (the client
// runs POST /auth/otp/request first, same endpoint used for forgot-password).
const signupSchema = z.object({
  phoneNumber: z.string().min(1),
  code: z.string().min(1),
  password: passwordSchema,
  displayName: z.string().min(1),
});

authRouter.post("/signup", async (req, res) => {
  const parsed = signupSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);
  const { phoneNumber, code, password, displayName } = parsed.data;

  const isValid = await verifyOtp(phoneNumber, code);
  if (!isValid) return res.status(401).json({ error: "Invalid or expired code" });

  const existing = await prisma.user.findUnique({ where: { phoneNumber } });
  if (existing) {
    return res.status(409).json({ error: "An account with this number already exists — log in instead" });
  }

  const user = await prisma.user.create({
    data: { phoneNumber, displayName, passwordHash: hashPassword(password) },
  });

  const token = issueToken(user.id);
  res.status(201).json({ token, user: toPublicUser(user) });
});

const loginSchema = z.object({
  phoneNumber: z.string().min(1),
  password: z.string().min(1),
});

authRouter.post("/login", async (req, res) => {
  const parsed = loginSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);
  const { phoneNumber, password } = parsed.data;

  const user = await prisma.user.findUnique({ where: { phoneNumber } });
  if (!user) return res.status(404).json({ error: "No account found for this number" });

  if (!user.passwordHash || !verifyPassword(password, user.passwordHash)) {
    return res.status(401).json({ error: "Incorrect phone number or password" });
  }

  const token = issueToken(user.id);
  res.json({ token, user: toPublicUser(user) });
});

const forgotPasswordSchema = z.object({ phoneNumber: z.string().min(1) });

authRouter.post("/password/forgot", async (req, res) => {
  const parsed = forgotPasswordSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);
  const { phoneNumber } = parsed.data;

  const user = await prisma.user.findUnique({ where: { phoneNumber } });
  if (!user) return res.status(404).json({ error: "No account found for this number" });

  await requestOtp(phoneNumber);
  res.json({ message: "OTP sent" });
});

const resetPasswordSchema = z.object({
  phoneNumber: z.string().min(1),
  code: z.string().min(1),
  newPassword: passwordSchema,
});

authRouter.post("/password/reset", async (req, res) => {
  const parsed = resetPasswordSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);
  const { phoneNumber, code, newPassword } = parsed.data;

  const isValid = await verifyOtp(phoneNumber, code);
  if (!isValid) return res.status(401).json({ error: "Invalid or expired code" });

  const user = await prisma.user.findUnique({ where: { phoneNumber } });
  if (!user) return res.status(404).json({ error: "No account found for this number" });

  await prisma.user.update({
    where: { id: user.id },
    data: { passwordHash: hashPassword(newPassword) },
  });

  res.json({ message: "Password updated" });
});

// Fetches the caller's own up-to-date user row. The mobile client caches
// `currentUser` in secure storage rather than re-fetching on every screen
// (there's no server-side session store to check against, a JWT alone
// doesn't carry fresh profile data), so that cache can drift from what's
// actually saved server-side — e.g. it only ever recorded paystackRecipientCode
// at first, before bankCode/accountNumber/accountName were added to what
// the client persists. This lets it re-sync on demand instead of staying
// stuck with whatever was true the moment it was first cached.
authRouter.get("/me", requireAuth, async (req: AuthedRequest, res) => {
  const user = await prisma.user.findUnique({ where: { id: req.userId! } });
  if (!user) return res.status(404).json({ error: "Account not found" });
  res.json(toPublicUser(user));
});

// Edits the signed-in user's own display name and/or profile photo.
// photoUrl is a base64 data URI, not a CDN link — there's no object
// storage wired up (PRD doesn't call for one yet), so it's stored inline
// on the User row. Capped well under Postgres's per-row limits since the
// client is expected to downscale/compress before sending it.
const MAX_PHOTO_DATA_URI_LENGTH = 2_000_000; // ~1.5MB of image data, base64-inflated

const updateProfileSchema = z.object({
  displayName: z.string().min(1).optional(),
  photoUrl: z.string().max(MAX_PHOTO_DATA_URI_LENGTH).nullable().optional(),
});

authRouter.patch("/me", requireAuth, async (req: AuthedRequest, res) => {
  const parsed = updateProfileSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);

  const user = await prisma.user.update({
    where: { id: req.userId! },
    data: parsed.data,
  });

  res.json(toPublicUser(user));
});

// Changing a password while already signed in is a different threat model
// from /password/reset (which proves phone ownership via OTP because the
// person doesn't have the old password to prove anything with) — here they
// already have a valid session *and* know the current password, so
// requiring the current password is the confirmation step, no OTP needed.
const changePasswordSchema = z.object({
  currentPassword: z.string().min(1),
  newPassword: passwordSchema,
});

authRouter.patch("/me/password", requireAuth, async (req: AuthedRequest, res) => {
  const parsed = changePasswordSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);
  const { currentPassword, newPassword } = parsed.data;

  const user = await prisma.user.findUnique({ where: { id: req.userId! } });
  if (!user || !user.passwordHash || !verifyPassword(currentPassword, user.passwordHash)) {
    return res.status(401).json({ error: "Incorrect current password" });
  }

  await prisma.user.update({
    where: { id: user.id },
    data: { passwordHash: hashPassword(newPassword) },
  });

  res.json({ message: "Password updated" });
});

// Registers this device's FCM token so it can receive push notifications.
// Called on login and on app launch (tokens can rotate) — idempotent, so
// calling it again with the same token is a harmless no-op rather than
// piling up duplicates.
const pushTokenSchema = z.object({ token: z.string().min(1) });

authRouter.post("/me/push-token", requireAuth, async (req: AuthedRequest, res) => {
  const parsed = pushTokenSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);

  const user = await prisma.user.findUniqueOrThrow({ where: { id: req.userId! } });
  if (!user.pushTokens.includes(parsed.data.token)) {
    await prisma.user.update({
      where: { id: user.id },
      data: { pushTokens: { push: parsed.data.token } },
    });
  }

  res.json({ message: "Token registered" });
});

// Removes a device's token — called on logout so a signed-out device stops
// receiving pushes meant for whoever's signed into it next.
authRouter.delete("/me/push-token", requireAuth, async (req: AuthedRequest, res) => {
  const parsed = pushTokenSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);

  const user = await prisma.user.findUniqueOrThrow({ where: { id: req.userId! } });
  await prisma.user.update({
    where: { id: user.id },
    data: { pushTokens: { set: user.pushTokens.filter((t) => t !== parsed.data.token) } },
  });

  res.json({ message: "Token removed" });
});

// Permanently ends this person's account. Doesn't hard-delete the row —
// Expense/ExpenseSplit/Settlement rows tied to this user are *shared* group
// history (other members' balances depend on them), and there's no
// onDelete: Cascade on those relations on purpose, so a raw DELETE would
// throw a foreign-key violation the moment this user has ever paid or split
// an expense. Instead this scrubs every personal identifier and marks
// deletedAt, so the account can never log in again (passwordHash is wiped,
// and verifyPassword above already rejects a null hash) while group history
// stays intact for everyone else. phoneNumber is replaced with a tombstone
// value, not left as-is or nulled, so the real number is freed up for
// someone else to sign up with and this row still satisfies the column's
// NOT NULL + @unique constraints.
const deleteAccountSchema = z.object({ password: z.string().min(1) });

authRouter.delete("/me", requireAuth, async (req: AuthedRequest, res) => {
  const parsed = deleteAccountSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);

  const user = await prisma.user.findUnique({ where: { id: req.userId! } });
  if (!user || !user.passwordHash || !verifyPassword(parsed.data.password, user.passwordHash)) {
    return res.status(401).json({ error: "Incorrect password" });
  }

  await prisma.user.update({
    where: { id: user.id },
    data: {
      phoneNumber: `deleted:${user.id}`,
      passwordHash: null,
      displayName: "Deleted user",
      photoUrl: null,
      bankCode: null,
      accountNumber: null,
      accountName: null,
      paystackRecipientCode: null,
      pushTokens: [],
      deletedAt: new Date(),
    },
  });

  res.json({ message: "Account deleted" });
});
