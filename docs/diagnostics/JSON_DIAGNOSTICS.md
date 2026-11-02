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
  "checkedFileCount": 1,
  "warnings": [],
  "diagnostics": [],
  "errors": []
}
```

`outcome` is `clean`, `findings` or `failed`. Any error takes precedence over
findings, but findings from other files are retained. File order follows input
order (sorted discovery for a project); findings preserve normal source order.

`checkedFileCount` counts file checks that completed successfully, including
files with lint findings. Read, parse, analysis, write, and fix errors do not
count as successful checks; command and discovery errors have count zero.
Duplicate explicit arguments count as separate checks. In fix mode this counts
successful post-fix results, not writes or edits.

`warnings` is an array of informational strings, separate from diagnostics and
errors. Successful project discovery selecting zero files emits a warning with
project-selection guidance; it remains `clean` with exit code 0 and count 0.
This includes empty `sources`, empty source directories, and fully excluded
sources. These additive version-1 fields appear on every lint/fix/watch report,
including command failures. JSON warnings remain in stdout, not stderr.
Consumers can enforce a nonzero count without scraping warning wording.
See [project selection](../features/empty-project-discovery.md).

Each diagnostic contains `rule`, `documentationUrl`, `severity` (always `error`),
`message`, `filename`, `range`, `help`, `symbol`, and `fixes`.
`documentationUrl` points to the registered rule's Markdown page on GitHub, for
example `https://github.com/jderochervlk/rescript-lint/blob/main/docs/rules/no-console.md`.
Namespaced IDs preserve their directory, such as `react/rules-of-hooks.md`.
Unregistered codes such as `syntax`, `suppression`, and infrastructure analysis
errors have a null documentation URL. The same field appears in diagnostics
nested under parse/analysis errors.

`help` is null or
`{"message": "Use the replacement API.", "url": "https://example.com/policy"}`;
its URL may be null. `symbol` is null or an object with `kind` (`value`, `module`,
or `type`) and the canonical `path`. These help/symbol metadata fields also
appear in LSP diagnostic `data`; human and LSP messages display the same
guidance. Custom `help.url` values remain independent from rule documentation.
LSP uses standard `codeDescription.href` for the documentation target, while
human CLI findings append a `Docs: URL` continuation.
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
object, documented in [CONFIGURATION.md](../configuration/CONFIGURATION.md).
