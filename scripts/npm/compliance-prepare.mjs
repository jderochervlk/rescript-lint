import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { spawnSync } from "node:child_process";
import dependencies from "./dependencies.json" with { type: "json" };
import compliance from "./compliance.cjs";

export function command(program, args, root, execute = spawnSync) {
  const result = execute(program, args, { cwd: root, encoding: "utf8", maxBuffer: 16 * 1024 * 1024 });
  return result.status === 0
    ? { _tag: "Output", text: result.stdout.trim() }
    : { _tag: "CommandFailed", message: `${program} ${args.join(" ")}: ${result.stderr || result.error || result.status}` };
}

export function verifyEnvironment(root, run = command) {
  const checks = dependencies.filter((item) => item.name !== "rescript").map((item) => ({
    program: "opam", args: ["var", "--cli=2.2", `${item.name}:version`], expected: item.version,
  }));
  const rescript = dependencies.find((item) => item.name === "rescript");
  const flow = dependencies.find((item) => item.name === "flow_parser");
  const revisions = [
    { program: "git", args: ["-C", "vendor/rescript", "rev-parse", "HEAD"], expected: rescript.revision },
    { program: "git", args: ["-C", "vendor/rescript", "status", "--porcelain"], expected: "" },
    { program: "opam", args: ["show", "--cli=2.2", "--field=vc-ref", "flow_parser"], expected: flow.revision },
    ...dependencies.filter((item) => !item.revision).map((item) => ({
      program: "opam", args: ["show", "--cli=2.2", "--field=pin", item.name], expected: "",
    })),
  ];
  for (const check of [...checks, ...revisions]) {
    const result = run(check.program, check.args, root);
    if (result._tag !== "Output") return result;
    if (result.text !== check.expected) return { _tag: "DependencyMismatch", message: `${check.args.join(" ")}: expected ${JSON.stringify(check.expected)}, got ${JSON.stringify(result.text)}.` };
  }
  return { _tag: "EnvironmentChecked" };
}

export async function archive(item, directory, fetchSource = fetch) {
  const path = join(directory, item.archive);
  if (!existsSync(path)) {
    const response = await fetchSource(item.url, { signal: AbortSignal.timeout(120000) });
    if (!response.ok) return { _tag: "DownloadFailed", message: `${item.url}: HTTP ${response.status}` };
    const bytes = Buffer.from(await response.arrayBuffer());
    if (compliance.digest(bytes, item.algorithm) !== item.digest) return { _tag: "ChecksumMismatch", message: `Source checksum mismatch: ${item.name}.` };
    writeFileSync(path, bytes);
  }
  return compliance.digest(readFileSync(path), item.algorithm) === item.digest
    ? { _tag: "Archive", path }
    : { _tag: "ChecksumMismatch", message: `Cached source checksum mismatch: ${item.name}. Remove ${path} and retry.` };
}

export function unpackNotices(item, path, workspace, output, run = command) {
  const extracted = join(workspace, item.name);
  mkdirSync(extracted);
  const result = run("tar", ["-xf", path, "--strip-components=1", "-C", extracted], workspace);
  if (result._tag !== "Output") return result;
  copyFileSync(path, join(output, "sources", item.archive));
  const notices = compliance.files(extracted).filter((file) => /^(licen[sc]e|copying|notice|copyright|authors)([._-].*)?$/i.test(file.split("/").at(-1)));
  for (const file of new Set([...item.licenses, ...notices])) {
    const destination = join(output, "licenses", item.name, file);
    mkdirSync(dirname(destination), { recursive: true });
    copyFileSync(join(extracted, file), destination);
  }
  return { _tag: "NoticesCopied" };
}

export function finishBundle(root, binary, output, run = command) {
  const sources = compliance.applicationFiles(root);
  const application = compliance.hashes(root, sources);
  const binaryHash = compliance.digest(readFileSync(binary));
  const result = run("tar", ["-czf", join(output, "application.tar.gz"), "--", ...sources], root);
  if (result._tag !== "Output") return result;
  if (binaryHash !== compliance.digest(readFileSync(binary))
    || JSON.stringify(application) !== JSON.stringify(compliance.hashes(root, compliance.applicationFiles(root)))) {
    return { _tag: "SourceChanged", message: "Source or binary changed during archiving; finish editing/building and prepare again." };
  }
  copyFileSync(join(root, "docs/REBUILD.md"), join(output, "REBUILD.md"));
  writeFileSync(join(output, "dependencies.json"), `${JSON.stringify(dependencies, null, 2)}\n`);
  const metadata = { binary: binaryHash, application,
    files: compliance.hashes(output, compliance.files(output)) };
  writeFileSync(join(output, "bundle.json"), `${JSON.stringify(metadata, null, 2)}\n`);
  return { _tag: "BundlePrepared", directory: output };
}

async function assemble({ root, binary, run, fetchSource }, workspace, downloads) {
  const output = join(workspace, "bundle");
  mkdirSync(join(output, "sources"), { recursive: true });
  for (const item of dependencies) {
    const downloaded = await archive(item, downloads, fetchSource);
    if (downloaded._tag !== "Archive") return downloaded;
    const copied = unpackNotices(item, downloaded.path, workspace, output, run);
    if (copied._tag !== "NoticesCopied") return copied;
  }
  return finishBundle(root, binary, output, run);
}

export async function prepareCompliance({ root, binary, run = command, fetchSource = fetch }) {
  try {
    const checked = verifyEnvironment(root, run);
    if (checked._tag !== "EnvironmentChecked") return checked;
    const base = join(root, "dist/compliance");
    const destination = join(base, "bundle");
    const downloads = join(base, "downloads");
    mkdirSync(downloads, { recursive: true });
    const workspace = mkdtempSync(join(base, "prepare-"));
    try {
      const result = await assemble({ root, binary, run, fetchSource }, workspace, downloads);
      if (result._tag !== "BundlePrepared") return result;
      rmSync(destination, { recursive: true, force: true });
      renameSync(result.directory, destination);
      return { _tag: "BundlePrepared", directory: destination };
    } finally {
      rmSync(workspace, { recursive: true, force: true });
    }
  } catch (error) {
    return { _tag: "CompliancePreparationFailed", message: `Cannot prepare license/source bundle: ${String(error)}` };
  }
}
