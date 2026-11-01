// API stdout is data, even when setup tools force color for human-readable logs.
export function createApi(command, environment) {
  const env = { ...environment, CLICOLOR_FORCE: "0", NO_COLOR: "1" };
  return (path, method = "GET", data) => JSON.parse(command("gh",
    ["api", path, "--method", method, ...(data === undefined ? [] : ["--input", "-"])],
    { env, ...(data === undefined ? {} : { input: JSON.stringify(data) }) }));
}
