# `test/no-duplicate-hooks`

Combine repeated same-scope lifecycle hooks into one hook.

- Category: `style`
- Enabled by default: No
- Autofix: No

Consolidating setup makes its execution order explicit. `false` disables this rule.

## Examples
### Incorrect
```rescript
open Vitest
beforeEach(resetDatabase)
beforeEach(resetClock)
```
### Correct
```rescript
open Vitest
beforeEach(() => {
  resetDatabase()
  resetClock()
})
```

## Configuration
```json
{"testFramework":"rescript-vitest-3","rules":{"test/no-duplicate-hooks":true}}
```
Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations
Analyzes recognized hooks within supported suite contexts, not arbitrary helper behavior.
