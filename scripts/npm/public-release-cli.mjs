import { auditPublicRelease } from "./public-release.mjs";

const result = await auditPublicRelease({ version: process.argv[2], request: fetch });
process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
if (result._tag !== "PublicReleaseAvailable") process.exitCode = 1;
