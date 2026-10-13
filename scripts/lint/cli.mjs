import { lint } from "./lint.mjs";

try {
  process.exitCode = lint();
} catch (error) {
  process.stderr.write(`OCaml lint failed: ${error.message}\n`);
  process.exitCode = 2;
}
