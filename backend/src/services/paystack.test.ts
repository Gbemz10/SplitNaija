import crypto from "crypto";
import { describe, it, expect, beforeAll } from "vitest";

const SECRET = "test-paystack-secret";

function sign(body: string): string {
  return crypto.createHmac("sha512", SECRET).update(body).digest("hex");
}

describe("verifyWebhookSignature", () => {
  // PAYSTACK_SECRET_KEY is read at module-load time, so it must be set
  // before the module under test is imported.
  beforeAll(() => {
    process.env.PAYSTACK_SECRET_KEY = SECRET;
  });

  it("accepts a valid signature over the exact raw body", async () => {
    const { verifyWebhookSignature } = await import("./paystack");
    const body = JSON.stringify({ event: "transfer.success", data: { reference: "abc-123" } });
    const signature = sign(body);

    expect(verifyWebhookSignature(body, signature)).toBe(true);
    expect(verifyWebhookSignature(Buffer.from(body), signature)).toBe(true);
  });

  it("rejects a tampered payload", async () => {
    const { verifyWebhookSignature } = await import("./paystack");
    const body = JSON.stringify({ event: "transfer.success", data: { reference: "abc-123" } });
    const signature = sign(body);

    const tampered = JSON.stringify({ event: "transfer.success", data: { reference: "abc-999" } });
    expect(verifyWebhookSignature(tampered, signature)).toBe(false);
  });

  it("rejects a signature produced with the wrong secret", async () => {
    const { verifyWebhookSignature } = await import("./paystack");
    const body = JSON.stringify({ event: "transfer.success", data: { reference: "abc-123" } });
    const wrongSignature = crypto.createHmac("sha512", "not-the-secret").update(body).digest("hex");

    expect(verifyWebhookSignature(body, wrongSignature)).toBe(false);
  });

  it("rejects a malformed/short signature without throwing", async () => {
    const { verifyWebhookSignature } = await import("./paystack");
    const body = JSON.stringify({ event: "transfer.success", data: { reference: "abc-123" } });

    expect(verifyWebhookSignature(body, "not-a-real-signature")).toBe(false);
  });
});
