import { join } from "node:path";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { packageName } from "../../npm/lib/platform.mjs";
import { verifyPublishers } from "./release-preflight.mjs";

export function releasePackages({ targets, manifest, artifacts }) {
  if (targets.length === 0) return [];
  const tarball = (target, name) => join(artifacts, `packages-${target.id}`,
    `${name.replace("@", "").replace("/", "-")}-${manifest.version}.tgz`);
  return [...targets.map(target => ({ name: packageName(target), tarball: tarball(target, packageName(target)) })),
    { name: manifest.name, tarball: tarball(targets[0], manifest.name) }];
}

async function stagePackages(packages, stage, onAccepted, onStaged, staged = []) {
  const [next, ...remaining] = packages;
  if (!next) return { _tag: "ReleaseStaged", packages: staged };
  const result = await stage(next);
  if (result._tag !== "PackageStaged") return { ...result, staged };
  onStaged(next.name);
  if (onAccepted) {
    if (typeof result.stageId !== "string" || !result.stageId) {
      return { _tag: "StageOutcomeUnknown", message: `Upload outcome for ${next.name} lacks a stage ID; inspect before retrying.`, staged };
    }
    await onAccepted(next, result.stageId);
  }
  return stagePackages(remaining, stage, onAccepted, onStaged, [...staged, next.name]);
}

export async function stageRelease({ packages, env, request, exists, stage, beginAttempt, onAccepted, completeAttempt, inspectAttempt }) {
  let attemptStarted = false;
  const accepted = [];
  try {
    if (packages.length === 0) return { _tag: "ReleaseInvalid", message: "No release packages were selected." };
    const missing = packages.find(entry => !exists(entry.tarball));
    if (missing) return { _tag: "ArtifactMissing", message: `Missing verified tarball for ${missing.name}: ${missing.tarball}` };
    const verifiedPackages = packages.map(entry => {
      const digest = `sha512-${createHash("sha512").update(readFileSync(entry.tarball)).digest("base64")}`;
      if (entry.digest && entry.digest !== digest) {
        throw new Error(`Verified artifact changed before staging: ${entry.name}`);
      }
      return { ...entry, digest };
    });
    const checked = await verifyPublishers({ packages: verifiedPackages.map(entry => entry.name), env, request });
    if (checked._tag !== "PublishersReady") return checked;
    if (beginAttempt) {
      const attempt = await beginAttempt(verifiedPackages);
      if (attempt?._tag === "AlreadyStaged") return attempt;
      attemptStarted = true;
    }
    const result = await stagePackages(verifiedPackages, stage, onAccepted,
      name => accepted.push(name));
    if (result._tag === "ReleaseStaged" && completeAttempt) await completeAttempt();
    if (result._tag !== "ReleaseStaged" && attemptStarted && inspectAttempt) {
      await inspectAttempt(result.message ?? `Staging stopped after ${result.staged.length} package(s)`);
    }
    return result;
  } catch {
    if (attemptStarted && inspectAttempt) {
      try {
        await inspectAttempt(`Protocol failure after ${accepted.length} accepted package(s); inspect before retrying.`);
      } catch {
        return { _tag: "StagingFailed", message:
          `Release staging protocol failed after ${accepted.length} accepted package(s); ledger inspection update failed. Manual inspection required.` };
      }
    }
    return { _tag: "StagingFailed", message:
      `Release staging failed after ${accepted.length} accepted package(s). Inspect npm stage list before retrying.` };
  }
}
