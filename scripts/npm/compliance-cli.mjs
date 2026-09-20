import { fileURLToPath } from "node:url";
import { join, resolve } from "node:path";
import { prepareCompliance } from "./compliance-prepare.mjs";

const root = resolve(process.argv[2] ?? fileURLToPath(new URL("../../", import.meta.url)));
const result = await prepareCompliance({ root, binary: join(root, "_build/default/bin/main.exe") });
if (result._tag === "BundlePrepared") {
  process.stdout.write(`License/source bundle prepared: ${result.directory}\n`);
} else {
  process.stderr.write(`${result.message}\n`);
  process.exitCode = 2;
}
