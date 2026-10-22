import {pathToFileURL} from "node:url";

const endpoint = "https://api.github.com/repos/ocaml/opam/releases";
const headerNames = [
  "date", "etag", "x-github-request-id", "x-cache", "age",
  "x-ratelimit-remaining", "x-ratelimit-reset", "retry-after",
];

// External text is bounded, cannot inject workflow commands, and cannot echo
// the credential even if a faulty server reflects it in an allowlisted field.
function publicText(value, token) {
  if (typeof value !== "string") return null;
  if (token && value.includes(token)) return "[redacted]";
  return value.slice(0, 160).replace(/[^a-zA-Z0-9 .,:;_/"=+-]/g, "?");
}

export function summarize(response, body, token, platform, architecture) {
  const headers = Object.fromEntries(headerNames.map(name =>
    [name, publicText(response.headers.get(name), token)]));
  const metadata = {status: response.status, headers};
  if (!response.ok) return {...metadata, observation: "http-error"};
  if (!Array.isArray(body) || body.length > 100 ||
      body.some(release => !release || typeof release.tag_name !== "string" ||
        !Array.isArray(release.assets) || release.assets.length > 200 ||
        release.assets.some(asset => !asset || typeof asset.name !== "string"))) {
    return {...metadata, observation: "malformed-releases"};
  }
  const suffix = `${architecture}-${platform}${platform === "windows" ? ".exe" : ""}`;
  return {...metadata, observation: "releases", count: body.length,
    releases: body.map(release => {
      const asset = release.assets.find(candidate => candidate.name.endsWith(suffix));
      return {
        tag: publicText(release.tag_name, token),
        platformBinary: Boolean(asset),
        detachedSignature: Boolean(asset &&
          release.assets.some(candidate => candidate.name === `${asset.name}.sig`)),
      };
    })};
}

export async function observe({token, platform, architecture, request = fetch}) {
  if (!token) return {observation: "missing-token"};
  try {
    const response = await request(endpoint, {
      headers: {authorization: `token ${token}`, accept: "application/vnd.github.v3+json"},
      redirect: "error",
      signal: AbortSignal.timeout(20000),
    });
    // Bound consumption even if the server ignores its default page size.
    let size = 0;
    const chunks = [];
    for await (const chunk of response.body ?? []) {
      size += chunk.length;
      if (size > 2 * 1024 * 1024) {
        return {status: response.status, observation: "body-too-large"};
      }
      chunks.push(Buffer.from(chunk));
    }
    let body;
    try {
      body = JSON.parse(Buffer.concat(chunks).toString("utf8"));
    } catch {
      return {status: response.status, observation: "invalid-json"};
    }
    return summarize(response, body, token, platform, architecture);
  } catch {
    // Never stringify exceptions: fetch errors can carry request credentials.
    return {observation: "request-failed"};
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  console.log(JSON.stringify({
    context: "Subsequent request after failed setup; not the action's original response",
    ...await observe({
      token: process.env.GITHUB_TOKEN,
      platform: {linux: "linux", darwin: "macos", win32: "windows"}[process.platform],
      architecture: {x64: "x86_64", arm64: "arm64"}[process.arch],
    }),
  }));
}
