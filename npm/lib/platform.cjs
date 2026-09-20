"use strict";

const targets = require("../targets.json");
const manifest = require("../package.json");

/** @typedef {{os: string, cpu: string, libc?: string}} Host */

/** @param {Host} host */
function selectTarget(host) {
  const target = targets.find((item) =>
    item.os === host.os && item.cpu === host.cpu && item.libc === host.libc);
  return target
    ? { _tag: "Target", target }
    : { _tag: "UnsupportedPlatform", message:
      `Unsupported platform: ${host.os}/${host.cpu}/${host.libc ?? "unknown libc"}. ` +
      "Supported targets are Linux glibc and macOS on x64/ARM64. Windows is deferred; Linux musl/Alpine is not supported." };
}

function packageName(target) {
  return `${manifest.name}-${target.id}`;
}

module.exports = { selectTarget, packageName };
