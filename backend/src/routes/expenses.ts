import { Router } from "express";
import { z } from "zod";
import { prisma } from "../lib/prisma";
import { requireAuth, AuthedRequest } from "../middleware/auth";
import { calculateSplits, SplitInput } from "../services/splitCalculator";
import { sendPushToUsers } from "../services/push";

// Minimal kobo->naira formatter for push notification bodies. Not the full
// currency-formatting concern the mobile app's formatKobo() handles (this
// backend has never needed one before — everything else it sends stays in
// raw kobo integers for the client to format), just enough for a readable
// notification string.
function formatNaira(amountKobo: number): string {
  return `₦${(amountKobo / 100).toLocaleString("en-NG", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

export const expensesRouter = Router();

expensesRouter.use(requireAuth);

const splitInputSchema = z.union([
  z.object({ type: z.literal("EQUAL"), participantIds: z.array(z.string()) }),
  z.object({
    type: z.literal("PERCENTAGE"),
    shares: z.array(z.object({ userId: z.string(), percentage: z.number() })),
  }),
  z.object({
    type: z.literal("CUSTOM"),
    shares: z.array(z.object({ userId: z.string(), amountKobo: z.number().int() })),
  }),
  z.object({
    type: z.literal("ITEMIZED"),
    items: z.array(
      z.object({ amountKobo: z.number().int(), assignedTo: z.array(z.string()) })
    ),
  }),
]);

const createExpenseSchema = z.object({
  groupId: z.string(),
  description: z.string().min(1),
  amountKobo: z.number().int().positive(),
  template: z
    .enum(["GENERIC", "OWAMBE_CONTRIBUTION", "AJO_ESUSU_ROUND", "SHARED_SUBSCRIPTION", "RENT"])
    .default("GENERIC"),
  category: z.string().optional(),
  note: z.string().optional(),
  photoUrl: z.string().optional(),
  split: splitInputSchema,
});

expensesRouter.post("/", async (req: AuthedRequest, res) => {
  const parsed = createExpenseSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json(parsed.error);
  const data = parsed.data;

  const group = await prisma.group.findUnique({ where: { id: data.groupId } });
  if (!group) return res.status(404).json({ error: "Group not found" });

  let shares;
  try {
    shares = calculateSplits(data.amountKobo, data.split as SplitInput);
  } catch (err) {
    return res.status(400).json({ error: (err as Error).message });
  }

  const expense = await prisma.expense.create({
    data: {
      groupId: data.groupId,
      payerId: req.userId!,
      description: data.description,
      amountKobo: data.amountKobo,
      splitType: data.split.type,
      template: data.template,
      category: data.category,
      note: data.note,
      photoUrl: data.photoUrl,
      splits: {
        create: shares.map((s) => ({ userId: s.userId, shareKobo: s.shareKobo })),
      },
    },
    include: {
      splits: true,
      payer: { select: { displayName: true } },
    },
  });

  // Notify everyone this expense was split with — except the payer, who
  // obviously already knows they just added it. Registered users only:
  // phone-only invitees (userId null on their GroupMember row) have no
  // account to hold a push token on in the first place.
  const otherParticipantIds = shares.map((s) => s.userId).filter((id) => id !== req.userId);
  if (otherParticipantIds.length > 0) {
    void sendPushToUsers(otherParticipantIds, {
      title: group.name,
      body: `${expense.payer.displayName} added "${data.description}" (${formatNaira(data.amountKobo)})`,
      data: { type: "expense_added", groupId: data.groupId, expenseId: expense.id },
    });
  }

  res.status(201).json(expense);
});

// Only the person who paid/added the expense can delete it — there's no
// separate "createdBy" column distinct from payerId (POST / always sets
// payerId to the caller), so payer is creator here. Splits reference the
// expense with no onDelete: Cascade (same reasoning as the group-delete
// route), so they have to go first, in a transaction, or the FK constraint
// rejects the Expense delete.
expensesRouter.delete("/:id", async (req: AuthedRequest, res) => {
  const expense = await prisma.expense.findUnique({ where: { id: req.params.id } });
  if (!expense) return res.status(404).json({ error: "Expense not found" });
  if (expense.payerId !== req.userId) {
    return res.status(403).json({ error: "Only the person who added this expense can delete it" });
  }

  await prisma.$transaction([
    prisma.expenseSplit.deleteMany({ where: { expenseId: expense.id } }),
    prisma.expense.delete({ where: { id: expense.id } }),
  ]);

  res.json({ message: "Expense deleted" });
});

expensesRouter.get("/group/:groupId", async (req, res) => {
  const expenses = await prisma.expense.findMany({
    where: { groupId: req.params.groupId },
    include: {
      splits: true,
      // Explicit select (not `payer: true`) so this never leaks passwordHash
      // to other group members viewing the expense list.
      payer: { select: { id: true, phoneNumber: true, displayName: true } },
    },
    orderBy: { createdAt: "desc" },
  });
  res.json(expenses);
});
