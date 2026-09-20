"use strict";

const { createHash } = require("node:crypto");
const { cpSync, readFileSync, readdirSync } = require("node:fs");
const { join } = require("node:path");
const dependencies = require("./dependencies.json");

const digest = (bytes, algorithm = "sha256") => createHash(algorithm).update(bytes).digest("hex");

function files(directory, prefix = "") {
  return readdirSync(join(directory, prefix), { withFileTypes: true }).flatMap((entry) => {
    const path = prefix ? `${prefix}/${entry.name}` : entry.name;
    return entry.isDirectory() ? files(directory, path) : [path];
  }).sort();
}

function applicationFiles(root) {
  const directories = ["bin", "lib", "vendor/parser"];
  return ["LICENSE", "dune", "dune-project", "rescript_linter.opam", "rescript_linter.opam.template", "vendor/dune",
    ...directories.flatMap((directory) => files(join(root, directory))
      .filter((file) => /(^|\/)dune$|\.(ml|mli|mll|c|h)$/.test(file))
      .map((file) => `${directory}/${file}`))].sort();
}

function hashes(root, paths) {
  return Object.fromEntries(paths.map((path) => [path, digest(readFileSync(join(root, path)))]));
}

function requiredFiles() {
  return ["REBUILD.md", "application.tar.gz", "dependencies.json",
    ...dependencies.flatMap((dependency) => [
      `sources/${dependency.archive}`,
      ...dependency.licenses.map((path) => `licenses/${dependency.name}/${path}`),
    ])];
}

function sourceProblem(root, binary, directory, metadata) {
  const checks = [
    [metadata.binary === digest(readFileSync(binary)), "Binary changed since source preparation."],
    [JSON.stringify(metadata.application) === JSON.stringify(hashes(root, applicationFiles(root))), "Application sources changed."],
    [readFileSync(join(directory, "REBUILD.md"), "utf8") === readFileSync(join(root, "docs/REBUILD.md"), "utf8"), "Rebuild instructions changed."],
  ];
  return checks.find(([matches]) => !matches)?.[1];
}

function dependencyProblem(directory) {
  const packaged = JSON.parse(readFileSync(join(directory, "dependencies.json"), "utf8"));
  if (JSON.stringify(packaged) !== JSON.stringify(dependencies)) return "Dependency inventory changed.";
  return dependencies.some((item) => digest(readFileSync(join(directory, "sources", item.archive)), item.algorithm) !== item.digest)
    ? "Dependency archive checksum mismatch." : undefined;
}

function validateBundle(root, binary, directory) {
  const metadata = JSON.parse(readFileSync(join(directory, "bundle.json"), "utf8"));
  const paths = files(directory).filter((file) => file !== "bundle.json");
  if (requiredFiles().some((path) => !paths.includes(path))) return "Required source or license material is missing.";
  if (JSON.stringify(metadata.files) !== JSON.stringify(hashes(directory, paths))) return "Bundle content changed.";
  return sourceProblem(root, binary, directory, metadata) ?? dependencyProblem(directory);
}

function stageCompliance({ root, binary, destination }) {
  const directory = join(root, "dist/compliance/bundle");
  try {
    const problem = validateBundle(root, binary, directory);
    if (problem) return { _tag: "ComplianceInvalid", message: `${problem} Run npm run prepare:licenses again.` };
    cpSync(directory, destination, { recursive: true });
    return { _tag: "ComplianceStaged" };
  } catch (error) {
    return { _tag: "ComplianceUnavailable", message: `Cannot stage license/source bundle; run npm run prepare:licenses. ${String(error)}` };
  }
}

module.exports = { digest, files, applicationFiles, hashes, requiredFiles, validateBundle, stageCompliance };
