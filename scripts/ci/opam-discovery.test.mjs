import assert from "node:assert/strict";
import {test} from "node:test";
import {observe, summarize} from "./opam-discovery.mjs";

const token = "fixture-secret";
const response = (body, status = 200, headers = {}) =>
  new Response(JSON.stringify(body), {status, headers});
const release = {tag_name: "2.6.1", assets: [
  {name: "opam-2.6.1-x86_64-linux"},
  {name: "opam-2.6.1-x86_64-linux.sig"},
]};
const run = request => observe({token, platform: "linux", architecture: "x86_64", request});

test("one authenticated default-page request and signed platform assets", async () => {
  let calls = 0;
  const result = await run(async (url, options) => {
    calls++;
    assert.equal(url, "https://api.github.com/repos/ocaml/opam/releases");
    assert.equal(options.headers.authorization, `token ${token}`);
    assert.equal(options.redirect, "error");
    return response([release]);
  });
  assert.equal(calls, 1);
  assert.equal(result.count, 1);
  assert.deepEqual(result.releases, [
    {tag: "2.6.1", platformBinary: true, detachedSignature: true},
  ]);
});

test("empty, malformed, rate limited, invalid JSON and thrown errors are distinct", async () => {
  assert.equal((await run(async () => response([]))).count, 0);
  for (const body of [{}, [null], [{tag_name: "x", assets: [null]}]]) {
    assert.equal((await run(async () => response(body))).observation, "malformed-releases");
  }
  assert.equal((await run(async () => response({message: token}, 403))).observation, "http-error");
  assert.equal((await run(async () => new Response("not json"))).observation, "invalid-json");
  assert.equal((await run(async () => { throw new Error(token); })).observation, "request-failed");
});

test("only allowlisted bounded fields are emitted and credentials are redacted", () => {
  const result = summarize(response([], 200, {
    etag: token, authorization: token, "x-cache": "cache-value ".repeat(100),
  }), [{...release, tag_name: token, body: token}], token, "windows", "x86_64");
  const output = JSON.stringify(result);
  assert.ok(!output.includes(token));
  assert.ok(!output.includes("authorization"));
  assert.equal(result.headers["x-cache"].length, 160);
  assert.equal(result.releases[0].platformBinary, false);
});

test("missing token makes no request", async () => {
  assert.deepEqual(await observe({request: () => assert.fail("unexpected request")}),
    {observation: "missing-token"});
});

test("oversized bodies are bounded and signatures must match the binary", async () => {
  assert.equal((await run(async () => new Response("x".repeat(2 * 1024 * 1024 + 1))))
    .observation, "body-too-large");
  const result = await run(async () => response([{...release,
    assets: [release.assets[0], {name: "other.sig"}]}]));
  assert.equal(result.releases[0].platformBinary, true);
  assert.equal(result.releases[0].detachedSignature, false);
});

test("HTTP errors retain status and diagnostic headers regardless of body format", async () => {
  for (const body of ["<html>unavailable</html>", "x".repeat(2 * 1024 * 1024 + 1)]) {
    const result = await run(async () => new Response(body, {
      status: 503,
      headers: {"x-github-request-id": "fixture-request", "retry-after": "60"},
    }));
    assert.equal(result.observation, "http-error");
    assert.equal(result.status, 503);
    assert.equal(result.headers["x-github-request-id"], "fixture-request");
    assert.equal(result.headers["retry-after"], "60");
  }
});
