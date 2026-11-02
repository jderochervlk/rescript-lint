# `test/no-identical-title`

Require unique literal titles among sibling registrations of the same kind.

- Category: `style`
- Enabled by default: No
- Autofix: No

Distinct titles make failures easier to identify. `false` disables this rule.

## Examples
### Incorrect
```rescript
open Vitest
describe("name normalization", () => {
  test("trims", t => {
    t->expect(String.trim(" Ada"))->Expect.toBe("Ada")
  })
  test("trims", t => {
    t->expect(String.trim("Ada "))->Expect.toBe("Ada")
  })
})
```
### Correct
```rescript
open Vitest
describe("name normalization", () => {
  test("trims leading spaces", t => {
    t->expect(String.trim(" Ada"))->Expect.toBe("Ada")
  })
  test("trims trailing spaces", t => {
    t->expect(String.trim("Ada "))->Expect.toBe("Ada")
  })
})
```

## Configuration
```json
{"testFramework":"rescript-vitest-3","rules":{"test/no-identical-title":true}}
```
Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations
Compares literal sibling titles of the same registration kind; dynamic titles and non-sibling duplication are not detected.

See [examples](../RULE_EXAMPLES.md#test-framework-rules) and [boundaries](../EXTENDED_RULES.md#test-rules).
