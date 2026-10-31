import targets from "../../npm/targets.json" with { type: "json" };
import manifest from "../../npm/package.json" with { type: "json" };
import { packageName } from "../../npm/lib/platform.mjs";

async function publicManifest(name, version, request) {
  try {
    const response = await request(
      `https://registry.npmjs.org/${encodeURIComponent(name)}/${encodeURIComponent(version)}`,
      { method: "GET", signal: AbortSignal.timeout(15000) });
    if (response.status === 404) return { _tag: "MissingVersion", name, version };
    if (!response.ok) return { _tag: "RegistryError", name, version, status: response.status };
    const body = await response.json();
    return body?.name === name && body.version === version
      ? { _tag: "PublicVersion", manifest: body }
      : { _tag: "InvalidManifest", name, version };
  } catch {
    return { _tag: "RegistryError", name, version };
  }
}

export async function auditPublicRelease({ version, request }) {
  if (typeof version !== "string" || !/^0\.1\.0-alpha\.\d+$/.test(version)) {
    return { _tag: "InvalidVersion", message: "Supply an explicit 0.1.0-alpha.N version." };
  }
  const launcher = await publicManifest(manifest.name, version, request);
  if (launcher._tag !== "PublicVersion") return launcher;
  const dependencies = launcher.manifest.optionalDependencies;
  const expected = targets.map(packageName);
  if (!dependencies || Object.keys(dependencies).length !== expected.length ||
      !expected.every(name => dependencies[name] === version)) {
    return { _tag: "InvalidDependencies", name: manifest.name, version,
      message: "Published launcher must reference every supported native package at the exact release version." };
  }
  const results = await Promise.all(expected.map(name => publicManifest(name, dependencies[name], request)));
  const failures = results.filter(result => result._tag !== "PublicVersion");
  return failures.length > 0
    ? { _tag: "IncompleteRelease", version, failures }
    : { _tag: "PublicReleaseAvailable", version, packages: [manifest.name, ...expected] };
}
