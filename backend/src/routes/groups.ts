import { Router } from "express";
import { z } from "zod";
import { randomBytes } from "crypto";
import { prisma } from "../lib/prisma";
import { requireAuth, AuthedRequest } from "../middleware/auth";

export const groupsRouter = Router();

// Public: powers the lightweight web-view link non-registered invitees see
// before installing the app (PRD §7.1) — must stay reachable without a
// session token, so it's registered before the router-wide requireAuth below.
groupsRouter.get("/preview/:inviteCode", async (req, res) => {
  const group = await prisma.group.findUnique({
    where: { inviteCode: req.params.inviteCode },
    include: { members: true },
  });
  if (!group) return res.status(404).json({ error: "Group not found" });
  res.json({ id: group.id, name: group.name, memberCount: group.members.length });
});

groupsRouter.use(requireAuth);

const createGroupSchema = z.object({
  name: z.string().min(1),
});

groupsRouter.post("/", async (req: AuthedRequest, res) => {
  const parsed = createGroupSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);

  const inviteCode = randomBytes(4).toString("hex");
  const user = await prisma.user.findUniqueOrThrow({ where: { id: req.userId! } });

  const group = await prisma.group.create({
    data: {
      name: parsed.data.name,
      inviteCode,
      members: {
        create: {
          userId: user.id,
          phoneNumber: user.phoneNumber,
          displayName: user.displayName,
          isRegistered: true,
        },
      },
    },
    include: { members: true },
  });

  res.status(201).json(group);
});

// Lists every group the authenticated user belongs to.
groupsRouter.get("/", async (req: AuthedRequest, res) => {
  const memberships = await prisma.groupMember.findMany({
    where: { userId: req.userId! },
    include: { group: true },
    orderBy: { joinedAt: "desc" },
  });

  res.json(memberships.map((m) => m.group));
});

const joinGroupSchema = z.object({ inviteCode: z.string() });

groupsRouter.post("/join", async (req: AuthedRequest, res) => {
  const parsed = joinGroupSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);

  const group = await prisma.group.findUnique({ where: { inviteCode: parsed.data.inviteCode } });
  if (!group) return res.status(404).json({ error: "Group not found" });

  const user = await prisma.user.findUniqueOrThrow({ where: { id: req.userId! } });

  const member = await prisma.groupMember.upsert({
    where: { groupId_phoneNumber: { groupId: group.id, phoneNumber: user.phoneNumber } },
    update: { userId: user.id, isRegistered: true },
    create: {
      groupId: group.id,
      userId: user.id,
      phoneNumber: user.phoneNumber,
      displayName: user.displayName,
      isRegistered: true,
    },
  });

  res.json(member);
});

// Lists every member of a group (registered + phone-only) — feeds the
// split participant picker on mobile.
groupsRouter.get("/:groupId/members", async (req, res) => {
  const members = await prisma.groupMember.findMany({
    where: { groupId: req.params.groupId },
    orderBy: { joinedAt: "asc" },
  });
  res.json(members);
});

// Add a participant by phone number who hasn't installed the app yet —
// the WhatsApp non-user flow, PRD §7.5.
const addNonUserSchema = z.object({
  phoneNumber: z.string(),
  displayName: z.string(),
});

groupsRouter.post("/:groupId/members/invite", async (req, res) => {
  const parsed = addNonUserSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);

  const group = await prisma.group.findUnique({ where: { id: req.params.groupId } });
  if (!group) return res.status(404).json({ error: "Group not found" });

  const member = await prisma.groupMember.create({
    data: {
      groupId: req.params.groupId,
      phoneNumber: parsed.data.phoneNumber,
      displayName: parsed.data.displayName,
      isRegistered: false,
    },
  });

  // TODO Phase 2: trigger WhatsApp message with web-view link (PRD §6.2/§7.5)

  res.status(201).json(member);
});
