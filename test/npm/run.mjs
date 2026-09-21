import { globSync } from "node:fs";
import { resolve } from "node:path";
import { run } from "node:test";
import { spec } from "node:test/reporters";

const sources = globSync(["npm/**/*.mjs", "scripts/npm/*.{cjs,mjs}"]).map((path) => resolve(path));
const stream = run({
  files: globSync("test/npm/*.test.{cjs,mjs}"),
  coverage: true,
  coverageIncludeGlobs: sources,
  lineCoverage: 90, branchCoverage: 90, functionCoverage: 90,
});

stream.on("test:fail", () => { process.exitCode = 1; });
stream.on("test:coverage", ({ summary }) => {
  const missing = sources.filter((path) => !summary.files.some((file) => file.path === path));
  const under = [...summary.files, summary.totals].filter((file) =>
    [file.coveredLinePercent, file.coveredBranchPercent, file.coveredFunctionPercent]
      .some((percent) => !Number.isFinite(percent) || percent < 90));
  if (missing.length > 0 || under.length > 0) {
    const belowThreshold = under.map((file) => ({ path: file.path ?? "overall",
      lines: file.coveredLinePercent, branches: file.coveredBranchPercent,
      functions: file.coveredFunctionPercent }));
    process.stderr.write(`Coverage gate failed: ${JSON.stringify({ missing, belowThreshold }, null, 2)}\n`);
    process.exitCode = 1;
  }
});
stream.compose(spec).pipe(process.stdout);
