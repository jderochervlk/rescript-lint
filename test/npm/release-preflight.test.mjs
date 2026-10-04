import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import targets from "../../npm/targets.json" with { type: "json" };
import manifest from "../../npm/package.json" with { type: "json" };
import { packageName } from "../../npm/lib/platform.mjs";
import { verifyPublishers } from "../../scripts/npm/release-preflight.mjs";

const packages = [...targets.map(packageName), manifest.name];
const env = { ACTIONS_ID_TOKEN_REQUEST_URL: "https://oidc.example/token?job=release",
  ACTIONS_ID_TOKEN_REQUEST_TOKEN: "fixture-request-token" };
const response = (body, status = 200) => ({ ok: status === 200, status, json: async () => body });

test("authorizes every native package and launcher before publication", async () => {
  const calls = [];
  const request = async (url, options) => {
    calls.push(String(url));
    if (calls.length === 1) {
      assert.equal(new URL(url).searchParams.get("audience"), "npm:registry.npmjs.org");
      assert.equal(options.headers.Authorization, "Bearer fixture-request-token");
      return response({ value: "fixture-oidc-token" });
    }
    assert.equal(options.method, "POST");
    assert.equal(options.headers.Authorization, "Bearer fixture-oidc-token");
    return response({ token: "fixture-npm-token" });
  };
  assert.deepEqual(await verifyPublishers({ packages, env, request }), { _tag: "PublishersReady" });
  assert.deepEqual(calls.slice(1), packages.map(name =>
    `https://registry.npmjs.org/-/npm/v1/oidc/token/exchange/package/${encodeURIComponent(name)}`));
});

test("stops on an unbootstrapped new target without attempting later packages", async () => {
  const calls = [];
  const request = async (url) => {
    calls.push(String(url));
    if (calls.length === 1) return response({ value: "fixture-token" });
    return String(url).includes("darwin-x64") ? response({}, 404) : response({ token: "fixture-token" });
  };
  const checked = await verifyPublishers({ packages, env, request });
  assert.equal(checked._tag, "PublisherUnavailable");
  assert.match(checked.message, /rescript-lint-darwin-x64.*HTTP 404/);
  assert.equal(calls.length, 4);
});

test("rejects missing permissions and unsuccessful or malformed token responses", async () => {
  for (const missing of [{}, { ACTIONS_ID_TOKEN_REQUEST_URL: env.ACTIONS_ID_TOKEN_REQUEST_URL }]) {
    assert.equal((await verifyPublishers({ packages, env: missing, request: async () => assert.fail("Unexpected request") }))._tag, "OidcUnavailable");
  }
  for (const body of [null, {}, { value: 1 }, { value: "" }]) {
    assert.equal((await verifyPublishers({ packages, env, request: async () => response(body) }))._tag, "OidcUnavailable");
  }
  assert.equal((await verifyPublishers({ packages, env, request: async () => response({}, 403) }))._tag, "OidcUnavailable");
  for (const body of [null, {}, { token: 1 }, { token: "" }]) {
    const request = async url => String(url).includes("oidc.example")
      ? response({ value: "fixture-token" }) : response(body);
    assert.equal((await verifyPublishers({ packages, env, request }))._tag, "PublisherUnavailable");
  }
});

test("reports network and decoding failures without exposing credentials", async () => {
  const request = async () => Promise.reject(new Error("fixture-request-token"));
  const checked = await verifyPublishers({ packages, env, request });
  assert.equal(checked._tag, "PreflightFailed");
  assert.doesNotMatch(checked.message, /fixture-request-token/);
});

test("preflight CLI reports readiness or exits before publication", () => {
  const script = fileURLToPath(new URL("../../scripts/npm/release-preflight-cli.mjs", import.meta.url));
  const failed = spawnSync(process.execPath, [script], { encoding: "utf8",
    env: { ...process.env, ACTIONS_ID_TOKEN_REQUEST_URL: "", ACTIONS_ID_TOKEN_REQUEST_TOKEN: "" } });
  assert.equal(failed.status, 2);
  assert.match(failed.stderr, /id-token: write/);
  const setup = 'globalThis.fetch = async url => ({ok: true, json: async () => String(url).includes("oidc.example") ? {value: "fixture-token"} : {token: "fixture-token"}});';
  const ready = spawnSync(process.execPath, ["--import", `data:text/javascript,${encodeURIComponent(setup)}`, script],
    { encoding: "utf8", env: { ...process.env, ...env } });
  assert.equal(ready.status, 0, ready.stderr);
  assert.match(ready.stdout, /every release package/);
});
