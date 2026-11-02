# `test/no-disabled-tests`

Disallow tests skipped or marked as todo.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Skipped tests silently stop providing coverage. Re-enable them or remove obsolete cases. `false` disables this rule.

## Examples
### Incorrect
```rescript
open Vitest
test("trims names", ~skip=true, t => {
  t->expect(String.trim(" Ada "))->Expect.toBe("Ada")
})
```
### Correct
```rescript
open Vitest
test("trims names", t => {
  t->expect(String.trim(" Ada "))->Expect.toBe("Ada")
})
```

## Configuration
```json
{"testFramework":"rescript-vitest-3","rules":{"test/no-disabled-tests":true}}
```
Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations
Recognizes Todo registrations and resolved `skip`/`skipIf(true)` uses; dynamic `skipIf` is not presumed true. Missing adapter is an analysis error.

See [examples](../RULE_EXAMPLES.md#test-framework-rules) and [boundaries](../EXTENDED_RULES.md#test-rules).
