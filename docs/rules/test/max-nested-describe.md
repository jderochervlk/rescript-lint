# `test/max-nested-describe`

Limit nesting depth of describe suites.

- Category: `style`
- Enabled by default: No
- Autofix: No

Deeply nested suites obscure test context. The default maximum depth is five; this example configures two. `false` disables the rule.

## Examples
### Incorrect
```rescript
open Vitest
describe("user", () => {
  describe("admin", () => {
    describe("permissions", permissionsTests)
  })
})
```
### Correct
```rescript
open Vitest
describe("admin permissions", () => {
  describe("write access", permissionsTests)
})
```

## Configuration
```json
{"testFramework":"rescript-vitest-3","maxNestedDescribe":2,"rules":{"test/max-nested-describe":true}}
```
Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations
Counts recognized suite nesting; custom wrapper functions are not treated as suites unless resolved as supported registrations.

See [examples](../RULE_EXAMPLES.md#test-framework-rules) and [boundaries](../EXTENDED_RULES.md#test-rules).
