# `test/no-focused-tests`

Disallow focused Vitest tests that exclude the rest of the suite.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Remove `only` before committing so the complete suite executes. `false` disables the rule.

## Examples
### Incorrect
```rescript
open Vitest
test("trims names", ~only=true, t => {
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

Focus may also be applied to a suite, excluding sibling suites and tests.

### Incorrect: suite registration

```rescript
open Vitest
describe("name normalization", ~only=true, () => {
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
{"testFramework":"rescript-vitest-3","rules":{"test/no-focused-tests":true}}
```
Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations
Uses resolved supported Vitest registrations; dynamic wrappers may be unknown.
Missing required adapter or analysis metadata is an analysis error, not a clean
result.
