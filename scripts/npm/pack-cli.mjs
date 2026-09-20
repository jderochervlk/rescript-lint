import { fileURLToPath } from "node:url";
import { packForHost } from "./pack.mjs";

const root = fileURLToPath(new URL("../../", import.meta.url));
const result = packForHost({ root, runtime: process });
if (result._tag !== "Packed") {
  process.stderr.write(`${result.message}\n`);
  process.exitCode = 2;
}
