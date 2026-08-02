import { Router } from "express";
import { z } from "zod";
import { prisma } from "../lib/prisma";
import { requireAuth, AuthedRequest } from "../middleware/auth";
import { calculateSplits, SplitInput } from "../services/splitCalculator";

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
    include: { splits: true },
  });

  res.status(201).json(expense);
});

expensesRouter.get("/group/:groupId", async (req, res) => {
  const expenses = await prisma.expense.findMany({
    where: { groupId: req.params.groupId },
    include: { splits: true, payer: true },
    orderBy: { createdAt: "desc" },
  });
  res.json(expenses);
});
