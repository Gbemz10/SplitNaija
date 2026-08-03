/**
 * Creates (or resets) one stable test account so you can exercise the Login
 * screen without going through the OTP signup wizard every time.
 *
 * Run from backend/: npm run seed:test-user
 */
import "dotenv/config";
import { prisma } from "../src/lib/prisma";
import { hashPassword } from "../src/services/password";

const PHONE = "+2348012345678";
const PASSWORD = "Test1234!";
const DISPLAY_NAME = "Test User";

async function main() {
  const user = await prisma.user.upsert({
    where: { phoneNumber: PHONE },
    update: { passwordHash: hashPassword(PASSWORD) },
    create: { phoneNumber: PHONE, displayName: DISPLAY_NAME, passwordHash: hashPassword(PASSWORD) },
  });

  console.log("Seeded test login:");
  console.log(`  phone:    ${user.phoneNumber}  (type "8012345678" in the app — the +234 is fixed)`);
  console.log(`  password: ${PASSWORD}`);
  console.log(`  name:     ${user.displayName}`);
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
