import { test } from "node:test";
import assert from "node:assert/strict";
import { createApi } from "../../scripts/version/github-api.mjs";

test("API decoding disables inherited forced color without changing the caller environment", () => {
  const environment = Object.freeze({
    CLICOLOR_FORCE: "1", NO_COLOR: "1", GH_FORCE_TTY: "80",
    GH_TOKEN: "fixture-token-not-a-credential", GH_HOST: "github.example.invalid",
    PATH: "fixture-path", OPAMCOLOR: "always",
  });
  const api = createApi((_program, _args, options) => {
    assert.notEqual(options.env, environment);
    assert.deepEqual(options.env, { ...environment, CLICOLOR_FORCE: "0", NO_COLOR: "1" });
    const json = '{"object":{"sha":"main-sha"}}';
    return options.env.CLICOLOR_FORCE !== "0" ? `\u001b[1;37m${json}\u001b[0m` : json;
  }, environment);
  assert.deepEqual(api("repos/owner/repo/git/ref/heads/main"), { object: { sha: "main-sha" } });
  assert.equal(environment.CLICOLOR_FORCE, "1");
  assert.equal(environment.OPAMCOLOR, "always");
});

test("API GET defaults retain the endpoint and omit stdin", () => {
  const api = createApi((program, args, options) => {
    assert.equal(program, "gh");
    assert.deepEqual(args, ["api", "repos/owner/repo/pulls?page=2", "--method", "GET"]);
    assert.deepEqual(options, { env: { CLICOLOR_FORCE: "0", NO_COLOR: "1" } });
    return ' [ {"number": 2} ] \n';
  }, {});
  assert.deepEqual(api("repos/owner/repo/pulls?page=2"), [{ number: 2 }]);
});

test("API POST preserves JSON bodies through stdin rather than shell interpolation", () => {
  const data = Object.freeze({
    query: "query($id: ID!) { node(id: $id) { id } }",
    variables: Object.freeze({ id: "PR_1", text: "quotes \" and $shell\ntext" }),
  });
  const api = createApi((program, args, options) => {
    assert.equal(program, "gh");
    assert.deepEqual(args, ["api", "graphql", "--method", "POST", "--input", "-"]);
    assert.equal(options.input, JSON.stringify(data));
    assert.equal(options.env.CLICOLOR_FORCE, "0");
    assert.equal(options.env.NO_COLOR, "1");
    return '{"data":{"node":{"id":"PR_1"}}}';
  }, {});
  assert.deepEqual(api("graphql", "POST", data), { data: { node: { id: "PR_1" } } });
});

test("API decoding remains strict for malformed or unexpectedly decorated responses", () => {
  for (const response of ["not JSON", "\u001b[1;37m{\"ok\":true}\u001b[0m"]) {
    const api = createApi(() => response, { CLICOLOR_FORCE: "1" });
    assert.throws(() => api("repos/owner/repo"), SyntaxError);
  }
});

test("API command failures propagate without decoding or fallback requests", () => {
  const failure = new Error("fixture command failed");
  const api = createApi(() => { throw failure; }, {});
  assert.throws(() => api("repos/owner/repo"), error => error === failure);
});
