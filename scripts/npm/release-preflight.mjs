async function githubToken(env, request) {
  const url = new URL(env.ACTIONS_ID_TOKEN_REQUEST_URL);
  url.searchParams.set("audience", "npm:registry.npmjs.org");
  const response = await request(url, {
    headers: { Authorization: `Bearer ${env.ACTIONS_ID_TOKEN_REQUEST_TOKEN}` },
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) return { _tag: "OidcUnavailable", message: `GitHub OIDC request failed (HTTP ${response.status}).` };
  const body = await response.json();
  return body && typeof body.value === "string" && body.value.length > 0
    ? { _tag: "OidcToken", token: body.value }
    : { _tag: "OidcUnavailable", message: "GitHub did not return an OIDC token." };
}

async function publisher(packageName, token, request) {
  const url = `https://registry.npmjs.org/-/npm/v1/oidc/token/exchange/package/${encodeURIComponent(packageName)}`;
  const response = await request(url, {
    method: "POST", headers: { Authorization: `Bearer ${token}` },
    signal: AbortSignal.timeout(15000),
  });
  if (!response.ok) return { _tag: "PublisherUnavailable", message: `Trusted-publisher authentication is not ready for ${packageName} (HTTP ${response.status}). Complete the package bootstrap before staging.` };
  const body = await response.json();
  return body && typeof body.token === "string" && body.token.length > 0
    ? { _tag: "PublisherReady" }
    : { _tag: "PublisherUnavailable", message: `npm did not return an authentication token for ${packageName}.` };
}

export async function verifyPublishers({ packages, env, request }) {
  if (!env.ACTIONS_ID_TOKEN_REQUEST_URL || !env.ACTIONS_ID_TOKEN_REQUEST_TOKEN) {
    return { _tag: "OidcUnavailable", message: "GitHub OIDC requires id-token: write." };
  }
  try {
    const token = await githubToken(env, request);
    if (token._tag !== "OidcToken") return token;
    for (const name of packages) {
      const checked = await publisher(name, token.token, request);
      if (checked._tag !== "PublisherReady") return checked;
    }
    return { _tag: "PublishersReady" };
  } catch {
    return { _tag: "PreflightFailed", message: "Trusted-publisher authentication preflight failed; no packages were staged." };
  }
}
