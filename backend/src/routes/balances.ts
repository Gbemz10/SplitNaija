import { Router } from "express";
import { prisma } from "../lib/prisma";
import { requireAuth } from "../middleware/auth";
import { computeNetBalances, simplifyDebts } from "../services/debtSimplification";

export const balancesRouter = Router();

balancesRouter.use(requireAuth);

// Running balance per group + minimized settle-up transactions (PRD §7.3)
balancesRouter.get("/group/:groupId", async (req, res) => {
  const expenses = await prisma.expense.findMany({
    where: { groupId: req.params.groupId },
    include: { splits: true },
  });

  const payments = expenses.map((e) => ({ payerId: e.payerId, amountKobo: e.amountKobo }));
  const splits = expenses.flatMap((e) =>
    e.splits.map((s) => ({ userId: s.userId, shareKobo: s.shareKobo }))
  );

  // Net out already-confirmed settlements too, so paid-off debts don't
  // keep showing up in the simplified transaction list.
  const confirmedSettlements = await prisma.settlement.findMany({
    where: { groupId: req.params.groupId, status: "CONFIRMED" },
  });

  const netBalances = computeNetBalances(splits, payments, confirmedSettlements);
  const transactions = simplifyDebts(netBalances);

  res.json({ netBalances, suggestedSettlements: transactions });
});
