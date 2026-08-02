import { describe, it, expect } from "vitest";
import { computeNetBalances, simplifyDebts } from "./debtSimplification";

describe("computeNetBalances", () => {
  it("2-person simple debt", () => {
    // A paid 1000 for an expense split evenly between A and B -> B owes A 500
    const balances = computeNetBalances(
      [
        { userId: "A", shareKobo: 500 },
        { userId: "B", shareKobo: 500 },
      ],
      [{ payerId: "A", amountKobo: 1000 }]
    );

    expect(balances).toEqual(
      expect.arrayContaining([
        { userId: "A", balanceKobo: 500 },
        { userId: "B", balanceKobo: -500 },
      ])
    );
    expect(balances).toHaveLength(2);
  });

  it("3+ person chain (A owes B, B owes C)", () => {
    // Expense 1: A pays 300, split A/B/C evenly (100 each) -> B owes 100, C owes 100, A is owed 200
    // Expense 2: B pays 300, split A/B/C evenly (100 each) -> now A owes 100 net, C owes 200 net, B is owed 200
    const splits = [
      { userId: "A", shareKobo: 100 },
      { userId: "B", shareKobo: 100 },
      { userId: "C", shareKobo: 100 },
      { userId: "A", shareKobo: 100 },
      { userId: "B", shareKobo: 100 },
      { userId: "C", shareKobo: 100 },
    ];
    const payments = [
      { payerId: "A", amountKobo: 300 },
      { payerId: "B", amountKobo: 300 },
    ];

    const balances = computeNetBalances(splits, payments);
    const byUser = Object.fromEntries(balances.map((b) => [b.userId, b.balanceKobo]));

    expect(byUser).toEqual({ A: 100, B: 100, C: -200 });

    const transactions = simplifyDebts(balances);
    const totalMoved = transactions.reduce((sum, t) => sum + t.amountKobo, 0);
    expect(totalMoved).toBe(200);
    // C (the only debtor) must pay exactly the sum owed
    expect(transactions.every((t) => t.fromUserId === "C")).toBe(true);
  });

  it("group that nets to exactly zero produces no balances or transactions", () => {
    const balances = computeNetBalances(
      [
        { userId: "A", shareKobo: 500 },
        { userId: "B", shareKobo: 500 },
      ],
      [
        { payerId: "A", amountKobo: 500 },
        { payerId: "B", amountKobo: 500 },
      ]
    );

    expect(balances).toEqual([]);
    expect(simplifyDebts(balances)).toEqual([]);
  });

  it("odd kobo remainder is not lost or duplicated", () => {
    // 1000 kobo split 3 ways -> 334/333/333 (see splitCalculator remainder logic)
    const splits = [
      { userId: "A", shareKobo: 334 },
      { userId: "B", shareKobo: 333 },
      { userId: "C", shareKobo: 333 },
    ];
    const payments = [{ payerId: "A", amountKobo: 1000 }];

    const balances = computeNetBalances(splits, payments);
    const totalAbs = balances.reduce((sum, b) => sum + Math.abs(b.balanceKobo), 0);
    // A is owed 666 (334+333+333 owed to A minus A's own 334 share = 666),
    // B owes 333, C owes 333 -> sums of debtor side and creditor side match exactly
    const debtorTotal = balances.filter((b) => b.balanceKobo < 0).reduce((s, b) => s - b.balanceKobo, 0);
    const creditorTotal = balances.filter((b) => b.balanceKobo > 0).reduce((s, b) => s + b.balanceKobo, 0);
    expect(debtorTotal).toBe(creditorTotal);
    expect(totalAbs).toBe(debtorTotal + creditorTotal);

    const transactions = simplifyDebts(balances);
    const totalMoved = transactions.reduce((sum, t) => sum + t.amountKobo, 0);
    expect(totalMoved).toBe(creditorTotal);
  });

  it("a CONFIRMED settlement reduces the remaining suggested transactions", () => {
    // B owes A 500. A CONFIRMED settlement of 500 from B to A should net to zero.
    const rawBalances = computeNetBalances(
      [
        { userId: "A", shareKobo: 500 },
        { userId: "B", shareKobo: 500 },
      ],
      [{ payerId: "A", amountKobo: 1000 }]
    );
    expect(simplifyDebts(rawBalances)).toEqual([{ fromUserId: "B", toUserId: "A", amountKobo: 500 }]);

    const nettedBalances = computeNetBalances(
      [
        { userId: "A", shareKobo: 500 },
        { userId: "B", shareKobo: 500 },
      ],
      [{ payerId: "A", amountKobo: 1000 }],
      [{ fromUserId: "B", toUserId: "A", amountKobo: 500 }]
    );

    expect(nettedBalances).toEqual([]);
    expect(simplifyDebts(nettedBalances)).toEqual([]);
  });

  it("a partial CONFIRMED settlement leaves the correct remainder", () => {
    const nettedBalances = computeNetBalances(
      [
        { userId: "A", shareKobo: 500 },
        { userId: "B", shareKobo: 500 },
      ],
      [{ payerId: "A", amountKobo: 1000 }],
      [{ fromUserId: "B", toUserId: "A", amountKobo: 200 }]
    );

    const byUser = Object.fromEntries(nettedBalances.map((b) => [b.userId, b.balanceKobo]));
    expect(byUser).toEqual({ A: 300, B: -300 });
    expect(simplifyDebts(nettedBalances)).toEqual([{ fromUserId: "B", toUserId: "A", amountKobo: 300 }]);
  });
});

describe("simplifyDebts", () => {
  it("matches largest debtor to largest creditor first", () => {
    const balances = [
      { userId: "A", balanceKobo: -700 },
      { userId: "B", balanceKobo: -300 },
      { userId: "C", balanceKobo: 1000 },
    ];
    const transactions = simplifyDebts(balances);

    expect(transactions).toEqual([
      { fromUserId: "A", toUserId: "C", amountKobo: 700 },
      { fromUserId: "B", toUserId: "C", amountKobo: 300 },
    ]);
  });

  it("handles an empty balance list", () => {
    expect(simplifyDebts([])).toEqual([]);
  });
});
