# `test/require-top-level-describe`

Group top-level test registrations in a describe suite.

- Category: `style`
- Enabled by default: No
- Autofix: No

Suites provide a clear grouping boundary for test files. `false` disables this rule.

## Examples
### Incorrect
```rescript
open Vitest
test("trims names", t => {
  t->expect(String.trim(" Ada "))->Expect.toBe("Ada")
})
```
### Correct
```rescript
open Vitest
describe("name normalization", () => {
  test("trims names", t => {
    t->expect(String.trim(" Ada "))->Expect.toBe("Ada")
  })
})
```

## Configuration
```json
{"testFramework":"rescript-vitest-3","rules":{"test/require-top-level-describe":true}}
```
Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations
Checks resolved supported top-level registrations; helper-generated registrations may not be known.

See [examples](../RULE_EXAMPLES.md#test-framework-rules) and [boundaries](../EXTENDED_RULES.md#test-rules).
