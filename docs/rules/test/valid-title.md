# `test/valid-title`

Require a nonempty test or suite title.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Titles identify registrations in test output; provide a meaningful description. `false` disables this rule.

## Examples
### Incorrect
```rescript
open Vitest
test("", t => {
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
{"testFramework":"rescript-vitest-3","rules":{"test/valid-title":true}}
```
Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations
Checks statically known registration titles; dynamic expressions may not be evaluated.

See [examples](../RULE_EXAMPLES.md#test-framework-rules) and [boundaries](../EXTENDED_RULES.md#test-rules).
