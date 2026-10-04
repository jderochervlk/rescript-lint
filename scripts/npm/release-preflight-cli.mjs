import targets from "../../npm/targets.json" with { type: "json" };
import manifest from "../../npm/package.json" with { type: "json" };
import { packageName } from "../../npm/lib/platform.mjs";
import { verifyPublishers } from "./release-preflight.mjs";

const result = await verifyPublishers({
  packages: [...targets.map(packageName), manifest.name], env: process.env, request: fetch,
});
if (result._tag !== "PublishersReady") {
  process.stderr.write(`${result.message}\n`);
  process.exitCode = 2;
} else {
  process.stdout.write("Trusted publishing is ready for every release package.\n");
}
