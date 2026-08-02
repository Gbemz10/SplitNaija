/**
 * Turns an expense + split method into per-member shares (in kobo).
 * PRD §7.2 — split methods: equal, percentage, custom, itemized.
 */

export type SplitInput =
  | { type: "EQUAL"; participantIds: string[] }
  | { type: "PERCENTAGE"; shares: { userId: string; percentage: number }[] }
  | { type: "CUSTOM"; shares: { userId: string; amountKobo: number }[] }
  | { type: "ITEMIZED"; items: { amountKobo: number; assignedTo: string[] }[] };

export function calculateSplits(
  amountKobo: number,
  input: SplitInput
): { userId: string; shareKobo: number }[] {
  switch (input.type) {
    case "EQUAL": {
      const n = input.participantIds.length;
      if (n === 0) throw new Error("EQUAL split needs at least one participant");
      const base = Math.floor(amountKobo / n);
      const remainder = amountKobo - base * n;
      // distribute the leftover kobo (from integer division) one at a time
      // so the split always sums exactly to amountKobo
      return input.participantIds.map((userId, idx) => ({
        userId,
        shareKobo: base + (idx < remainder ? 1 : 0),
      }));
    }

    case "PERCENTAGE": {
      const totalPct = input.shares.reduce((sum, s) => sum + s.percentage, 0);
      if (Math.abs(totalPct - 100) > 0.01) {
        throw new Error(`Percentages must sum to 100 (got ${totalPct})`);
      }
      let allocated = 0;
      const shares = input.shares.map((s, idx) => {
        const isLast = idx === input.shares.length - 1;
        const shareKobo = isLast
          ? amountKobo - allocated
          : Math.round((s.percentage / 100) * amountKobo);
        allocated += shareKobo;
        return { userId: s.userId, shareKobo };
      });
      return shares;
    }

    case "CUSTOM": {
      const total = input.shares.reduce((sum, s) => sum + s.amountKobo, 0);
      if (total !== amountKobo) {
        throw new Error(
          `Custom split amounts (${total}) must sum to expense total (${amountKobo})`
        );
      }
      return input.shares.map((s) => ({ userId: s.userId, shareKobo: s.amountKobo }));
    }

    case "ITEMIZED": {
      const totals = new Map<string, number>();
      for (const item of input.items) {
        const n = item.assignedTo.length;
        if (n === 0) continue;
        const base = Math.floor(item.amountKobo / n);
        const remainder = item.amountKobo - base * n;
        item.assignedTo.forEach((userId, idx) => {
          const share = base + (idx < remainder ? 1 : 0);
          totals.set(userId, (totals.get(userId) ?? 0) + share);
        });
      }
      return Array.from(totals.entries()).map(([userId, shareKobo]) => ({
        userId,
        shareKobo,
      }));
    }
  }
}
