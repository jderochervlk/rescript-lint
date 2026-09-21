import targets from "../targets.json" with { type: "json" };
import manifest from "../package.json" with { type: "json" };

/** @typedef {{os: string, cpu: string, libc?: string}} Host */

/** @param {Host} host */
export function selectTarget(host) {
  const target = targets.find((item) =>
    item.os === host.os && item.cpu === host.cpu && item.libc === host.libc);
  return target
    ? { _tag: "Target", target }
    : { _tag: "UnsupportedPlatform", message:
      `Unsupported platform: ${host.os}/${host.cpu}/${host.libc ?? "unknown libc"}. ` +
      "Supported targets are Linux glibc on x64/ARM64. macOS and Windows are deferred; Linux musl/Alpine is not supported." };
}

export function packageName(target) {
  return `${manifest.name}-${target.id}`;
}
