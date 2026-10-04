import { join } from "node:path";
import { packageName } from "../../npm/lib/platform.mjs";
import { verifyPublishers } from "./release-preflight.mjs";

export function releasePackages({ targets, manifest, artifacts }) {
  if (targets.length === 0) return [];
  const tarball = (target, name) => join(artifacts, `packages-${target.id}`,
    `${name.replace("@", "").replace("/", "-")}-${manifest.version}.tgz`);
  return [...targets.map(target => ({ name: packageName(target), tarball: tarball(target, packageName(target)) })),
    { name: manifest.name, tarball: tarball(targets[0], manifest.name) }];
}

function stagePackages(packages, stage, staged = []) {
  const [next, ...remaining] = packages;
  if (!next) return { _tag: "ReleaseStaged", packages: staged };
  const result = stage(next);
  return result._tag === "PackageStaged"
    ? stagePackages(remaining, stage, [...staged, next.name])
    : { ...result, staged };
}

export async function stageRelease({ packages, env, request, exists, stage }) {
  try {
    if (packages.length === 0) return { _tag: "ReleaseInvalid", message: "No release packages were selected." };
    const missing = packages.find(entry => !exists(entry.tarball));
    if (missing) return { _tag: "ArtifactMissing", message: `Missing verified tarball for ${missing.name}: ${missing.tarball}` };
    const checked = await verifyPublishers({ packages: packages.map(entry => entry.name), env, request });
    return checked._tag === "PublishersReady" ? stagePackages(packages, stage) : checked;
  } catch {
    return { _tag: "StagingFailed", message: "Release staging failed. Inspect npm stage list before retrying; no release versions were approved." };
  }
}
