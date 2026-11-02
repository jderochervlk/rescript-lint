# `test/expect-expect`

Require a recognized assertion in each test callback.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Tests without assertions can pass without verifying behavior. `false` disables this rule.

## Examples
### Incorrect
```rescript
open Vitest
let normalize = name => String.trim(name)
test("trims a user name", _ => normalize(" Ada ")->ignore)
```
### Correct
```rescript
open Vitest
let normalize = name => String.trim(name)
test("trims a user name", t => {
  let actual = normalize(" Ada ")
  t->expect(actual)->Expect.toBe("Ada")
})
```

## Configuration
```json
{"testFramework":"rescript-vitest-3","rules":{"test/expect-expect":true}}
```
Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations
Assertion detection is based on supported Vitest bindings and callback analysis; opaque helper assertions may not count. Missing adapter or required analysis context is an analysis error.

See [examples](../RULE_EXAMPLES.md#test-framework-rules) and [boundaries](../EXTENDED_RULES.md#test-rules).
