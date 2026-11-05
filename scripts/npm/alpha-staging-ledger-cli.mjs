import { spawnSync } from "node:child_process";
import { createApi } from "../version/github-api.mjs";
import { bootstrapLedger, readLedger } from "./alpha-staging-github-ledger.mjs";

const [command, ...args] = process.argv.slice(2);
const repository = process.env.GITHUB_REPOSITORY;
if (!repository || !process.env.GH_TOKEN) {
  throw new Error("Set GITHUB_REPOSITORY and GH_TOKEN from an explicitly authenticated operator session");
}
const api = createApi((executable, parameters, options) => {
  const result = spawnSync(executable, parameters, { ...options, encoding: "utf8" });
  if (result.status !== 0) throw new Error(result.stderr);
  return result.stdout;
}, process.env);

if (command === "inspect" && args.length === 0) {
  const current = await readLedger(api, repository);
  process.stdout.write(`${JSON.stringify({ tip: current.tip, ledger: current.ledger }, null, 2)}\n`);
} else if (command === "bootstrap" && args.length === 2 &&
    args[0] === "--confirm-bootstrap" && args[1]?.startsWith("--cutoff=")) {
  if (process.env.GITHUB_ACTIONS === "true") {
    throw new Error("Ledger bootstrap is an operator-only command, never an Actions job");
  }
  const cutoff = Number(args[1].slice("--cutoff=".length));
  if (!Number.isSafeInteger(cutoff) || cutoff < 1) {
    throw new Error("Supply the reviewed cutoff alpha counter");
  }
  const result = await bootstrapLedger({
    api, repository, authorized: true, cutoff,
  });
  process.stdout.write(`Initialized ${result.tip} with cutoff 0.1.0-alpha.${cutoff}.\n`);
} else {
  throw new Error("Usage: inspect | bootstrap --confirm-bootstrap --cutoff=N");
}
