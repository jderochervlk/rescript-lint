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
      "Linux musl/Alpine and Windows ARM64 are not supported yet." };
}

function packageName(target) {
  return `${manifest.name}-${target.id}`;
}

module.exports = { selectTarget, packageName };
