import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import targets from "../../npm/targets.json" with { type: "json" };
import manifest from "../../npm/package.json" with { type: "json" };
import { packageName } from "../../npm/lib/platform.mjs";
import { auditPublicRelease } from "../../scripts/npm/public-release.mjs";

const version = "0.1.0-alpha.3";
const dependencies = Object.fromEntries(targets.map(target => [packageName(target), version]));
const response = (body, status = 200) => ({ ok: status === 200, status, json: async () => body });
const publicBody = url => {
  const [name, requested] = new URL(url).pathname.slice(1).split("/").map(decodeURIComponent);
  return { name, version: requested, ...(name === manifest.name ? { optionalDependencies: dependencies } : {}) };
};

test("audits all five public native versions with GET only, independent of local version", async () => {
  const calls = [];
  const request = async (url, options) => {
    assert.equal(options.method, "GET");
    assert.equal(new URL(url).origin, "https://registry.npmjs.org");
    calls.push(publicBody(url).name);
    return response(publicBody(url));
  };
  const result = await auditPublicRelease({ version, request });
  assert.equal(result._tag, "PublicReleaseAvailable");
  assert.deepEqual(calls, [manifest.name, ...Object.keys(dependencies)]);
});

test("reports missing Windows even when all other platform packages exist", async () => {
  const request = async url => url.includes("win32-x64")
    ? response({ version: "0.0.0-stage" }, 404) : response(publicBody(url));
  assert.deepEqual(await auditPublicRelease({ version, request }), {
    _tag: "IncompleteRelease", version,
    failures: [{ _tag: "MissingVersion", name: "@jvlk/rescript-lint-win32-x64", version }],
  });
});

test("rejects absent, ranged, mismatched, missing-target and extra dependencies", async () => {
  const windows = "@jvlk/rescript-lint-win32-x64";
  const { [windows]: ignored, ...withoutWindows } = dependencies;
  for (const optionalDependencies of [undefined, {}, withoutWindows,
    { ...dependencies, [windows]: "^0.1.0-alpha.3" },
    { ...dependencies, [windows]: "0.1.0-alpha.4" },
    { ...dependencies, unexpected: version }]) {
    const request = async () => response({ name: manifest.name, version, optionalDependencies });
    assert.equal((await auditPublicRelease({ version, request }))._tag, "InvalidDependencies");
  }
});

test("distinguishes missing launcher, invalid metadata, transport and registry failures", async () => {
  for (const [request, tag] of [
    [async () => response({}, 404), "MissingVersion"],
    [async () => response({}, 403), "RegistryError"],
    [async () => { throw new Error("network"); }, "RegistryError"],
    [async () => ({ ok: true, json: async () => { throw new Error("json"); } }), "RegistryError"],
    ...[null, {}, { name: manifest.name, version: "0.0.0-stage" }].map(body =>
      [async () => response(body), "InvalidManifest"]),
  ]) {
    assert.equal((await auditPublicRelease({ version, request }))._tag, tag);
  }
  const request = async url => url.includes("win32-x64")
    ? response({}, 503) : response(publicBody(url));
  const result = await auditPublicRelease({ version, request });
  assert.equal(result._tag, "IncompleteRelease");
  assert.equal(result.failures[0]._tag, "RegistryError");
});

test("requires an exact alpha version before any request", async () => {
  for (const invalid of [undefined, 3, "alpha", "latest", "0.1.0-alpha.3/other"]) {
    assert.equal((await auditPublicRelease({ version: invalid,
      request: async () => assert.fail("Unexpected request") }))._tag, "InvalidVersion");
  }
});

test("CLI exits nonzero on unavailable release and zero on complete metadata", () => {
  const script = fileURLToPath(new URL("../../scripts/npm/public-release-cli.mjs", import.meta.url));
  const invalid = spawnSync(process.execPath, [script], { encoding: "utf8" });
  assert.equal(invalid.status, 1);
  assert.match(invalid.stdout, /InvalidVersion/);
  const setup = `globalThis.fetch = async url => ({ok: true, status: 200, json: async () => {
    const [name, version] = new URL(url).pathname.slice(1).split("/").map(decodeURIComponent);
    return {name, version, optionalDependencies: ${JSON.stringify(dependencies)}};
  }});`;
  const available = spawnSync(process.execPath,
    ["--import", `data:text/javascript,${encodeURIComponent(setup)}`, script, version], { encoding: "utf8" });
  assert.equal(available.status, 0, available.stderr);
  assert.match(available.stdout, /PublicReleaseAvailable/);
});
