import "dotenv/config";
import express from "express";
// Patches Express's router so a rejected promise in an async handler calls
// next(err) instead of becoming an unhandled rejection that crashes the
// process — Express 4 doesn't do this itself. Must be imported before routes
// are registered.
import "express-async-errors";
import { authRouter } from "./routes/auth";
import { groupsRouter } from "./routes/groups";
import { expensesRouter } from "./routes/expenses";
import { balancesRouter } from "./routes/balances";
import { settlementsRouter } from "./routes/settlements";

const app = express();

// Must be registered before express.json(): the Paystack webhook signature
// is an HMAC over the exact raw request bytes, and body-parser skips
// re-parsing once express.raw() has already set req.body/req._body for a
// matching path — so this has to run first, scoped to just this route.
app.use("/settlements/webhook/paystack", express.raw({ type: "application/json" }));
app.use(express.json());

app.get("/health", (_req, res) => res.json({ status: "ok" }));

app.use("/auth", authRouter);
app.use("/groups", groupsRouter);
app.use("/expenses", expensesRouter);
app.use("/balances", balancesRouter);
app.use("/settlements", settlementsRouter);

// Must be registered last: catches anything thrown or rejected by a route
// handler above so a single bad request returns a 500 instead of taking
// down the whole process.
app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(err);
  res.status(500).json({ error: "Internal server error" });
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => console.log(`SplitNaija API listening on :${PORT}`));
