import { describe, it, expect } from "vitest";
import { calculateSplits } from "./splitCalculator";

function sumShares(shares: { shareKobo: number }[]): number {
  return shares.reduce((sum, s) => sum + s.shareKobo, 0);
}

describe("calculateSplits — EQUAL", () => {
  it("divides evenly with no remainder", () => {
    const shares = calculateSplits(900, { type: "EQUAL", participantIds: ["A", "B", "C"] });
    expect(shares).toEqual([
      { userId: "A", shareKobo: 300 },
      { userId: "B", shareKobo: 300 },
      { userId: "C", shareKobo: 300 },
    ]);
  });

  it("distributes remainder kobo one at a time to the first N participants", () => {
    const shares = calculateSplits(1000, { type: "EQUAL", participantIds: ["A", "B", "C"] });
    expect(sumShares(shares)).toBe(1000);
    expect(shares).toEqual([
      { userId: "A", shareKobo: 334 },
      { userId: "B", shareKobo: 333 },
      { userId: "C", shareKobo: 333 },
    ]);
  });

  it("throws with zero participants", () => {
    expect(() => calculateSplits(1000, { type: "EQUAL", participantIds: [] })).toThrow();
  });
});

describe("calculateSplits — PERCENTAGE", () => {
  it("sums exactly to the total, with rounding error landing on the last participant", () => {
    // 33.33/33.33/33.34 of 1000 -> naive rounding could drift the total
    const shares = calculateSplits(1000, {
      type: "PERCENTAGE",
      shares: [
        { userId: "A", percentage: 33.33 },
        { userId: "B", percentage: 33.33 },
        { userId: "C", percentage: 33.34 },
      ],
    });
    expect(sumShares(shares)).toBe(1000);
    expect(shares[0].shareKobo).toBe(333);
    expect(shares[1].shareKobo).toBe(333);
    expect(shares[2].shareKobo).toBe(334); // last participant absorbs the remainder
  });

  it("rejects percentages that don't sum to 100", () => {
    expect(() =>
      calculateSplits(1000, {
        type: "PERCENTAGE",
        shares: [
          { userId: "A", percentage: 50 },
          { userId: "B", percentage: 40 },
        ],
      })
    ).toThrow(/must sum to 100/);
  });
});

describe("calculateSplits — CUSTOM", () => {
  it("accepts explicit amounts that sum to the total", () => {
    const shares = calculateSplits(1000, {
      type: "CUSTOM",
      shares: [
        { userId: "A", amountKobo: 600 },
        { userId: "B", amountKobo: 400 },
      ],
    });
    expect(shares).toEqual([
      { userId: "A", shareKobo: 600 },
      { userId: "B", shareKobo: 400 },
    ]);
  });

  it("rejects amounts that don't sum to the expense total", () => {
    expect(() =>
      calculateSplits(1000, {
        type: "CUSTOM",
        shares: [
          { userId: "A", amountKobo: 600 },
          { userId: "B", amountKobo: 300 },
        ],
      })
    ).toThrow(/must sum to expense total/);
  });
});

describe("calculateSplits — ITEMIZED", () => {
  it("splits each item evenly among its assignees, then sums per person across items", () => {
    const shares = calculateSplits(1000, {
      type: "ITEMIZED",
      items: [
        { amountKobo: 700, assignedTo: ["A", "B"] }, // 350/350
        { amountKobo: 300, assignedTo: ["B", "C"] }, // 150/150
      ],
    });
    const byUser = Object.fromEntries(shares.map((s) => [s.userId, s.shareKobo]));
    expect(byUser).toEqual({ A: 350, B: 500, C: 150 });
    expect(sumShares(shares)).toBe(1000);
  });

  it("distributes per-item remainder kobo without losing or duplicating it", () => {
    const shares = calculateSplits(1000, {
      type: "ITEMIZED",
      items: [{ amountKobo: 1000, assignedTo: ["A", "B", "C"] }],
    });
    const byUser = Object.fromEntries(shares.map((s) => [s.userId, s.shareKobo]));
    expect(byUser).toEqual({ A: 334, B: 333, C: 333 });
    expect(sumShares(shares)).toBe(1000);
  });
});
