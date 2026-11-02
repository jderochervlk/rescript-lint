# `no-unused-export`

Reports eligible public declarations with no project consumer, using compiler-generated Reanalyze metadata rather than a single-file reference count.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Run the compatible compiler and `rescript-tools reanalyze -dce -json` for the project, save the JSON report, then configure its path. Configured entry modules are exempt; declare application entry modules accurately.

## Examples

### Incorrect

```rescript
// src/Metrics.res: exported declaration has no project consumer.
let legacyCounter = () => 0
```

```rescript
// src/Main.res: the application entry point does not use Metrics.
let main = () => ()
```

### Correct

```text
Project layout:
src/Metrics.res
src/Main.res   (uses Metrics.recordRequest)
```

```rescript
// src/Metrics.res
let recordRequest = () => ()
```

```rescript
// src/Main.res
let main = () => Metrics.recordRequest()
```

## Configuration

```json
{
  "root": ".",
  "reanalyzeReport": "reanalyze.json",
  "entryModules": ["Main"],
  "rules": {
    "no-unused-export": true
  }
}
```

The project's `rescript.json` must discover `src`. Build with the compatible
compiler and create the report after saving all sources. For this example,
keep `main` live in Reanalyze as well as exempting the `Main` entry module in
the linter:

```sh
npx rescript build
npx rescript-tools reanalyze -dce -json -live-names main > reanalyze.json
npx rescript-lint --config rescript-lint.json
```

Regenerate the report after each source change. Choose real application entry
points for your project, rather than exempting unused library exports.
Set the rule to `false` to disable it.

## Limitations

Requires fresh, compatible Reanalyze JSON and matching `.cmt`/`.cmti` artifacts under `lib/ocaml` or legacy `lib/bs`. Missing, stale, malformed, or incompatible inputs fail analysis; timestamps are freshness checks, not cryptographic provenance. The linter does not launch the compiler or analyzer.
