# JSON Diagnostics

Use `rescript-lint --format json FILE.res`, optionally with `--fix`, `--watch`,
`--config` or `--project`. Human output remains the default. JSON is not a format
for help, version, rule listing, or the LSP transport; those combinations fail
explicitly. `--` ends option parsing. Repeated supported format options use the
last value; malformed options fail rather than being ignored.

Every run writes one compact JSON object followed by a newline to stdout.
Watch mode therefore produces JSON Lines, including clean runs. Watch status
messages remain on stderr. Exit codes are unchanged: clean `0`, findings `1`,
errors `2`. Watch remains running until interrupted even after a failed run.

## Schema Version 1

```json
{
  "schemaVersion": 1,
  "outcome": "clean",
  "exitCode": 0,
  "diagnostics": [],
  "errors": []
}
```

`outcome` is `clean`, `findings` or `failed`. Any error takes precedence over
findings, but findings from other files are retained. File order follows input
order (sorted discovery for a project); findings preserve normal source order.

Each diagnostic contains `rule`, `severity` (always `error`), `message`,
`filename`, `range`, `help`, `symbol`, and `fixes`. `help` is null or
`{"message": "Use the replacement API.", "url": "https://example.com/policy"}`;
its URL may be null. `symbol` is null or an object with `kind` (`value`, `module`,
or `type`) and the canonical `path`. These additive metadata fields also appear
in LSP diagnostic `data`; human and LSP messages display the same guidance.
Consumers must tolerate additional version-1 fields. `range.start` and
`range.end` contain one-based `line`, one-based UTF-8 byte `column`, and
zero-based absolute `byteOffset`. Ends are exclusive. These are not UTF-16 LSP
positions. Each fix contains zero-based inclusive `startByte`, exclusive
`endByte`, and replacement `text`.

Each error contains `kind`, `filename` (null for command errors), `message`,
and `diagnostics`. Kinds are `read`, `write`, `fix`, `unsupported-file`, `parse`,
`analysis`, and `command`. Parse/analysis diagnostics are nested inside their
error, not duplicated among top-level lint findings. Consumers should use
structured fields rather than parsing messages.

Fix mode reports remaining findings after the normal safe-fix checks. This
schema is not an applied-edit audit: it does not claim that listed fixes were
applied. JSON strings are encoded through the existing Yojson serializer.

`--inspect-config FILE --format json` emits a separate configuration-inspection
object, documented in [CONFIGURATION.md](CONFIGURATION.md).
