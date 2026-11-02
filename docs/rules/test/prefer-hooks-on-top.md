# `test/prefer-hooks-on-top`

Place suite lifecycle hooks before test registrations.

- Category: `style`
- Enabled by default: No
- Autofix: No

Keeping shared setup together at the beginning of a suite clarifies what applies to its tests. `false` disables this rule.

## Examples
### Incorrect
```rescript
open Vitest
let count = ref(0)
test("starts with no calls", t => {
  t->expect(count.contents)->Expect.toBe(0)
})
beforeEach(() => count.contents = 0)
```
### Correct
```rescript
open Vitest
let count = ref(0)
beforeEach(() => count.contents = 0)
test("starts with no calls", t => {
  t->expect(count.contents)->Expect.toBe(0)
})
```

## Configuration
```json
{"testFramework":"rescript-vitest-3","rules":{"test/prefer-hooks-on-top":true}}
```
Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations
Recognizes supported test/hook registrations in suite execution contexts.
