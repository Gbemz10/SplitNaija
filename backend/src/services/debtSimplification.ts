/**
 * Debt simplification (netting) — PRD §7.3.
 *
 * Given every expense split in a group, compute each member's net balance
 * (positive = owed money, negative = owes money), then produce the minimum
 * set of pairwise transactions that settles the group.
 *
 * Approach: greedy max-debtor-pays-max-creditor. Not provably minimal in the
 * general case (minimal-transaction netting is NP-hard for >3 balances),
 * but greedy gets within 1-2 transactions of optimal in practice and is
 * O(n log n) — plenty fast for typical group sizes (2-30 people).
 */

export interface NetBalance {
  userId: string;
  balanceKobo: number; // positive: is owed; negative: owes
}

export interface SimplifiedTransaction {
  fromUserId: string;
  toUserId: string;
  amountKobo: number;
}

export function computeNetBalances(
  splits: { userId: string; shareKobo: number }[],
  payments: { payerId: string; amountKobo: number }[],
  confirmedSettlements: { fromUserId: string; toUserId: string; amountKobo: number }[] = []
): NetBalance[] {
  const balances = new Map<string, number>();

  // Each payer is credited the full amount they paid
  for (const p of payments) {
    balances.set(p.payerId, (balances.get(p.payerId) ?? 0) + p.amountKobo);
  }

  // Each participant is debited their share
  for (const s of splits) {
    balances.set(s.userId, (balances.get(s.userId) ?? 0) - s.shareKobo);
  }

  // A CONFIRMED settlement moves real money: the payer's debt shrinks
  // (credit them), the payee's remaining credit shrinks (debit them) by
  // the same amount — otherwise a paid-off debt keeps showing up here.
  for (const s of confirmedSettlements) {
    balances.set(s.fromUserId, (balances.get(s.fromUserId) ?? 0) + s.amountKobo);
    balances.set(s.toUserId, (balances.get(s.toUserId) ?? 0) - s.amountKobo);
  }

  return Array.from(balances.entries())
    .map(([userId, balanceKobo]) => ({ userId, balanceKobo }))
    .filter((b) => b.balanceKobo !== 0);
}

export function simplifyDebts(balances: NetBalance[]): SimplifiedTransaction[] {
  // Work on a copy, sorted so we can always grab the biggest creditor/debtor
  const debtors = balances
    .filter((b) => b.balanceKobo < 0)
    .map((b) => ({ ...b }))
    .sort((a, b) => a.balanceKobo - b.balanceKobo); // most negative first

  const creditors = balances
    .filter((b) => b.balanceKobo > 0)
    .map((b) => ({ ...b }))
    .sort((a, b) => b.balanceKobo - a.balanceKobo); // most positive first

  const transactions: SimplifiedTransaction[] = [];
  let i = 0;
  let j = 0;

  while (i < debtors.length && j < creditors.length) {
    const debtor = debtors[i];
    const creditor = creditors[j];

    const amount = Math.min(-debtor.balanceKobo, creditor.balanceKobo);

    if (amount > 0) {
      transactions.push({
        fromUserId: debtor.userId,
        toUserId: creditor.userId,
        amountKobo: amount,
      });
      debtor.balanceKobo += amount;
      creditor.balanceKobo -= amount;
    }

    if (debtor.balanceKobo === 0) i++;
    if (creditor.balanceKobo === 0) j++;
  }

  return transactions;
}
