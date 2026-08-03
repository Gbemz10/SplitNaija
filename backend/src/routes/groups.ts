import { Router } from "express";
import { z } from "zod";
import { randomBytes } from "crypto";
import { prisma } from "../lib/prisma";
import { requireAuth, AuthedRequest } from "../middleware/auth";
import { computeNetBalances } from "../services/debtSimplification";
import { sendPushToUsers } from "../services/push";

export const groupsRouter = Router();

// Public: powers the lightweight web-view link non-registered invitees see
// before installing the app (PRD §7.1) — must stay reachable without a
// session token, so it's registered before the router-wide requireAuth below.
//
// Content-negotiated: a phone browser opening this link from a WhatsApp
// message (PRD §6.2/§7.5) gets a real branded HTML page, not raw JSON —
// there's no separate web frontend in this repo, so the backend renders it
// directly. `req.accepts(['html', 'json'])` defaults to 'html' when no
// Accept header is sent at all (most HTTP clients), which is the right
// default here since a person tapping a link in their chat app is what
// this endpoint actually exists for; anything that explicitly asks for
// JSON still gets it.
groupsRouter.get("/preview/:inviteCode", async (req, res) => {
  const group = await prisma.group.findUnique({
    where: { inviteCode: req.params.inviteCode },
    include: { members: true },
  });
  if (!group) {
    if (req.accepts(["html", "json"]) === "json") {
      return res.status(404).json({ error: "Group not found" });
    }
    return res.status(404).send(renderInvitePreviewHtml({ notFound: true }));
  }

  const memberCount = group.members.length;
  if (req.accepts(["html", "json"]) === "json") {
    return res.json({ id: group.id, name: group.name, memberCount });
  }
  res.send(renderInvitePreviewHtml({ groupName: group.name, memberCount, inviteCode: group.inviteCode }));
});

/**
 * A minimal, dependency-free HTML page — inline styles, no build step,
 * since this is the only page this backend will ever need to render.
 * Shows the invite code prominently (the actual mechanism for joining
 * right now: install the app, then enter this code) rather than a fake
 * "Open in app" button that would need real app-store listings and deep
 * link handling neither of which exist yet.
 */
function renderInvitePreviewHtml(
  params: { notFound: true } | { groupName: string; memberCount: number; inviteCode: string }
): string {
  const body = "notFound" in params
    ? `<p class="subtitle">This invite link isn't valid, or the group's been deleted.</p>`
    : `
      <p class="subtitle">You've been invited to split expenses in</p>
      <h1>${escapeHtml(params.groupName)}</h1>
      <p class="meta">${params.memberCount} ${params.memberCount === 1 ? "person" : "people"} already in this group</p>
      <div class="code-card">
        <div class="code-label">Your invite code</div>
        <div class="code">${escapeHtml(params.inviteCode)}</div>
      </div>
      <p class="instructions">Install SplitNaija, sign up, then enter this code to join the group.</p>
    `;

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>SplitNaija invite</title>
<style>
  * { box-sizing: border-box; }
  body {
    margin: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: #F7F6FA;
    color: #000;
    display: flex;
    min-height: 100vh;
    align-items: center;
    justify-content: center;
    padding: 24px;
  }
  .card {
    background: #fff;
    border-radius: 24px;
    padding: 32px 24px;
    max-width: 400px;
    width: 100%;
    text-align: center;
    box-shadow: 0 8px 32px rgba(0,0,0,0.08);
  }
  .wordmark {
    font-weight: 800;
    font-size: 15px;
    color: #6C2BD9;
    letter-spacing: 0.5px;
    margin-bottom: 24px;
  }
  h1 { font-size: 24px; font-weight: 800; margin: 4px 0 8px; }
  .subtitle { color: rgba(0,0,0,0.55); font-size: 14px; margin: 0; font-weight: 500; }
  .meta { color: rgba(0,0,0,0.55); font-size: 13px; margin: 0 0 24px; }
  .code-card {
    background: #F7F6FA;
    border-radius: 16px;
    padding: 20px;
    margin-bottom: 20px;
  }
  .code-label { color: rgba(0,0,0,0.45); font-size: 12px; font-weight: 600; margin-bottom: 6px; }
  .code { font-size: 30px; font-weight: 800; letter-spacing: 3px; color: #6C2BD9; }
  .instructions { color: rgba(0,0,0,0.6); font-size: 13px; line-height: 1.5; margin: 0; }
</style>
</head>
<body>
  <div class="card">
    <div class="wordmark">SplitNaija</div>
    ${body}
  </div>
</body>
</html>`;
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

groupsRouter.use(requireAuth);

const createGroupSchema = z.object({
  name: z.string().min(5),
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

// Lists every group the authenticated user belongs to, plus (per Splitwise's
// convention of color-coded per-row balances — green/red so you know at a
// glance without opening each group) this user's own net balance in each
// one: positive means the group owes them, negative means they owe the
// group, zero means settled up.
//
// Previously this just returned the bare Group row with no `members`
// relation loaded at all, so the mobile app's memberCount was always null
// and the "X members" line under each group name silently never rendered.
groupsRouter.get("/", async (req: AuthedRequest, res) => {
  const memberships = await prisma.groupMember.findMany({
    where: { userId: req.userId! },
    include: { group: { include: { _count: { select: { members: true } } } } },
    orderBy: { joinedAt: "desc" },
  });

  const groups = await Promise.all(
    memberships.map(async (m) => {
      const [expenses, confirmedSettlements] = await Promise.all([
        prisma.expense.findMany({ where: { groupId: m.groupId }, include: { splits: true } }),
        prisma.settlement.findMany({ where: { groupId: m.groupId, status: "CONFIRMED" } }),
      ]);
      const payments = expenses.map((e) => ({ payerId: e.payerId, amountKobo: e.amountKobo }));
      const splits = expenses.flatMap((e) => e.splits.map((s) => ({ userId: s.userId, shareKobo: s.shareKobo })));
      const netBalances = computeNetBalances(splits, payments, confirmedSettlements);
      const mine = netBalances.find((b) => b.userId === req.userId);

      return {
        id: m.group.id,
        name: m.group.name,
        inviteCode: m.group.inviteCode,
        memberCount: m.group._count.members,
        netBalanceKobo: mine?.balanceKobo ?? 0,
      };
    })
  );

  res.json(groups);
});

const joinGroupSchema = z.object({ inviteCode: z.string() });

groupsRouter.post("/join", async (req: AuthedRequest, res) => {
  const parsed = joinGroupSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);

  const group = await prisma.group.findUnique({ where: { inviteCode: parsed.data.inviteCode } });
  if (!group) return res.status(404).json({ error: "Group not found" });

  const user = await prisma.user.findUniqueOrThrow({ where: { id: req.userId! } });

  // Checked *before* the upsert so this reflects whether the caller was
  // already a member walking in — covers both "this is a group I created"
  // and "I already joined this with someone else's code before." Either
  // way the client shows the same "you're already in this group" toast
  // instead of silently re-joining with no feedback.
  const existing = await prisma.groupMember.findUnique({
    where: { groupId_phoneNumber: { groupId: group.id, phoneNumber: user.phoneNumber } },
  });

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

  // Only for a genuinely new join, not someone re-joining a group they were
  // already in (existing !== null) — that's not news to anyone. Only
  // registered members can hold a push token; phone-only invitees (userId
  // null) are skipped since they have no account to notify.
  if (existing === null) {
    const otherMembers = await prisma.groupMember.findMany({
      where: { groupId: group.id, userId: { not: null, notIn: [user.id] } },
      select: { userId: true },
    });
    const otherUserIds = otherMembers.map((m) => m.userId!).filter(Boolean);
    if (otherUserIds.length > 0) {
      void sendPushToUsers(otherUserIds, {
        title: group.name,
        body: `${user.displayName} joined the group.`,
        data: { type: "member_joined", groupId: group.id },
      });
    }
  }

  res.json({ ...member, groupName: group.name, alreadyMember: existing !== null });
});

// Lists every member of a group (registered + phone-only) — feeds the
// split participant picker on mobile.
groupsRouter.get("/:groupId/members", async (req, res) => {
  const members = await prisma.groupMember.findMany({
    where: { groupId: req.params.groupId },
    orderBy: { joinedAt: "asc" },
    // GroupMember keeps its own displayName/phoneNumber snapshot (needed
    // for phone-only invitees who aren't a real User row yet), but a
    // profile photo only exists on the User row — without this include, a
    // registered member's photo was never reachable here at all, so every
    // OTHER person's avatar in a group silently stayed initials-only no
    // matter what photo they'd set. Only registered members (userId set)
    // have a `user` to pull from; phone-only invitees get null, same as
    // before.
    include: { user: { select: { photoUrl: true } } },
  });
  res.json(members.map((m) => ({ ...m, photoUrl: m.user?.photoUrl ?? null, user: undefined })));
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

// Deletes a group and everything under it (expenses, splits, settlements,
// memberships). There's no separate ownerId column on Group — whoever's
// membership row has the earliest joinedAt is treated as the creator,
// since POST / always creates that first membership at group-creation
// time. Only that person can delete it; otherwise any member could nuke a
// group out from under everyone else sharing it.
groupsRouter.delete("/:groupId", async (req: AuthedRequest, res) => {
  const { groupId } = req.params;

  const group = await prisma.group.findUnique({ where: { id: groupId } });
  if (!group) return res.status(404).json({ error: "Group not found" });

  const firstMember = await prisma.groupMember.findFirst({
    where: { groupId },
    orderBy: { joinedAt: "asc" },
  });
  if (!firstMember || firstMember.userId !== req.userId) {
    return res.status(403).json({ error: "Only the group's creator can delete it" });
  }

  // Deleting a Group without cleaning up rows that reference it first
  // would fail on the foreign key constraints, since none of those
  // relations are set up with onDelete: Cascade. Order matters:
  // ExpenseSplit references Expense, so it goes first.
  await prisma.$transaction([
    prisma.expenseSplit.deleteMany({ where: { expense: { groupId } } }),
    prisma.expense.deleteMany({ where: { groupId } }),
    prisma.settlement.deleteMany({ where: { groupId } }),
    prisma.groupMember.deleteMany({ where: { groupId } }),
    prisma.group.delete({ where: { id: groupId } }),
  ]);

  res.status(204).send();
});
