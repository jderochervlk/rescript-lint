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

Vitest also exposes skip forms on suites. Remove the skip registration when
the scenario should execute; do not leave it silently excluded.

### Incorrect: suite registration

```rescript
open Vitest
describe("name normalization", ~skip=true, () => {
  test("trims names", _ => String.trim(" Ada ")->ignore)
})
```

### Correct: suite registration

```rescript
open Vitest
describe("name normalization", () => {
  test("trims names", _ => String.trim(" Ada ")->ignore)
})
```

## Configuration
```json
{"testFramework":"rescript-vitest-3","rules":{"test/no-disabled-tests":true}}
```
Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations
Recognizes Todo registrations and resolved `skip`/`skipIf(true)` uses; dynamic `skipIf` is not presumed true. Missing adapter is an analysis error.
