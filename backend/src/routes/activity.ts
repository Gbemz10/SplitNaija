import { Router } from "express";
import { prisma } from "../lib/prisma";
import { requireAuth, AuthedRequest } from "../middleware/auth";

export const activityRouter = Router();

const DEFAULT_LIMIT = 50;
const MAX_LIMIT = 200;

// A single merged, newest-first feed of expenses added and settlements
// sent/received across every group the caller belongs to. Exists so the
// mobile app's Activity tab can make one call instead of fetching every
// group's expenses individually and merging them client-side (which is
// what it did before this endpoint existed).
//
// Each item carries a `type` discriminator ("EXPENSE" | "SETTLEMENT") plus
// only the fields relevant to that type — the mobile model reads it as one
// tagged union rather than needing two separate response shapes.
activityRouter.get("/", requireAuth, async (req: AuthedRequest, res) => {
  const limitParam = Number(req.query.limit);
  const limit =
    Number.isFinite(limitParam) && limitParam > 0 ? Math.min(Math.floor(limitParam), MAX_LIMIT) : DEFAULT_LIMIT;

  const memberships = await prisma.groupMember.findMany({
    where: { userId: req.userId! },
    select: { groupId: true },
  });
  const groupIds = memberships.map((m) => m.groupId);

  if (groupIds.length === 0) return res.json([]);

  const [expenses, settlements] = await Promise.all([
    prisma.expense.findMany({
      // Being in the group isn't enough on its own — an expense someone
      // else paid and split only between themselves and a third member
      // (both also in this group) has nothing to do with the caller, and
      // showed up in their feed anyway before this. Only surface expenses
      // the caller actually has a stake in: they paid it, or they're one
      // of the people it was split between.
      where: {
        groupId: { in: groupIds },
        OR: [{ payerId: req.userId! }, { splits: { some: { userId: req.userId! } } }],
      },
      orderBy: { createdAt: "desc" },
      take: limit,
      include: {
        group: { select: { name: true } },
        payer: { select: { displayName: true } },
        // Powers the "who owes what" breakdown on the activity detail
        // screen — without this, tapping into an expense from Activity
        // could only show the headline amount, not the actual split.
        splits: { include: { user: { select: { displayName: true, photoUrl: true } } } },
      },
    }),
    prisma.settlement.findMany({
      // Only ever show settlements that actually completed. A PENDING or
      // FAILED row still gets created the moment "pay" is tapped (so it can
      // be tracked/retried), but rendering those in the activity feed made
      // every failed Paystack transfer look exactly like "You paid X" —
      // including once per retry, since each failed attempt creates its own
      // row. The feed is a record of what happened, not what was attempted.
      where: { OR: [{ fromUserId: req.userId! }, { toUserId: req.userId! }], status: "CONFIRMED" },
      orderBy: { createdAt: "desc" },
      take: limit,
      include: {
        group: { select: { name: true } },
        from: { select: { displayName: true } },
        to: { select: { displayName: true } },
      },
    }),
  ]);

  const items = [
    ...expenses.map((e) => ({
      type: "EXPENSE" as const,
      id: e.id,
      groupId: e.groupId,
      groupName: e.group.name,
      description: e.description,
      amountKobo: e.amountKobo,
      template: e.template,
      payerId: e.payerId,
      payerDisplayName: e.payer.displayName,
      createdAt: e.createdAt,
      splits: e.splits.map((s) => ({
        userId: s.userId,
        displayName: s.user.displayName,
        photoUrl: s.user.photoUrl,
        shareKobo: s.shareKobo,
      })),
    })),
    ...settlements.map((s) => ({
      type: "SETTLEMENT" as const,
      id: s.id,
      groupId: s.groupId,
      groupName: s.group.name,
      fromUserId: s.fromUserId,
      fromDisplayName: s.from.displayName,
      toUserId: s.toUserId,
      toDisplayName: s.to.displayName,
      amountKobo: s.amountKobo,
      status: s.status,
      createdAt: s.createdAt,
      confirmedAt: s.confirmedAt,
    })),
  ];

  // Each source query is independently capped at `limit`, so the merged
  // list can hold up to 2x that before this final sort+slice trims it back
  // down to a single, correctly-ordered page.
  items.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());

  res.json(items.slice(0, limit));
});
