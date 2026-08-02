import { Router } from "express";
import { z } from "zod";
import { prisma } from "../lib/prisma";
import { issueToken } from "../middleware/auth";
import { requestOtp, verifyOtp } from "../services/otp";

export const authRouter = Router();

const requestOtpSchema = z.object({ phoneNumber: z.string().min(1) });

authRouter.post("/otp/request", async (req, res) => {
  const parsed = requestOtpSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);

  await requestOtp(parsed.data.phoneNumber);
  res.json({ message: "OTP sent" });
});

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
  res.json({ token, user });
});
