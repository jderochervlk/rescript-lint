# `test/no-conditional-expect`

Keep assertions from being skipped by conditional branches in a test.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

An assertion hidden behind a condition may never run, leaving a test that appears to cover a case without checking it. `false` disables this rule.

## Examples
### Incorrect
```rescript
open Vitest
test("shows role", t => {
  if isAdmin {t->expect(label)->Expect.toBe("Administrator")}
})
```
### Correct
```rescript
open Vitest
test("shows role", t => {
  let expected = if isAdmin {"Administrator"} else {"Member"}
  t->expect(label)->Expect.toBe(expected)
})
```

## Configuration
```json
{"testFramework":"rescript-vitest-3","rules":{"test/no-conditional-expect":true}}
```
Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations
Recognizes assertions and conditional contexts in resolved supported test callbacks. Opaque helper callbacks may remain unknown.
