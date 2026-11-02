# `test/no-conditional-test`

Register tests unconditionally rather than inside runtime conditionals.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Conditional registration makes suite contents depend on execution environment. Put the condition in the test body instead. `false` disables this rule.

## Examples
### Incorrect
```rescript
open Vitest
let featureEnabled = true
if featureEnabled {
  test("feature is enabled", t => {
    t->expect(featureEnabled)->Expect.toBe(true)
  })
}
```
### Correct
```rescript
open Vitest
let featureEnabled = true
test("feature is enabled", t => {
  t->expect(featureEnabled)->Expect.toBe(true)
})
```

## Configuration
```json
{"testFramework":"rescript-vitest-3","rules":{"test/no-conditional-test":true}}
```
Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations
Checks registration in supported conditional execution contexts; arbitrary registration helpers are not whole-program analyzed.

See [examples](../RULE_EXAMPLES.md#test-framework-rules) and [boundaries](../EXTENDED_RULES.md#test-rules).
