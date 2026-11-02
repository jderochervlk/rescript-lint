# `test/prefer-hooks-in-order`

Declare lifecycle hooks in `beforeAll`, `beforeEach`, `afterEach`, `afterAll` order.

- Category: `style`
- Enabled by default: No
- Autofix: No

Consistent ordering makes lifecycle intent easier to scan. Setup hooks also
have an order within their category, as do teardown hooks. Set the rule to
`false` to disable it.

## Examples
### Incorrect
```rescript
open Vitest
afterEach(cleanup)
beforeEach(setup)
```
### Correct
```rescript
open Vitest
beforeEach(setup)
afterEach(cleanup)
```

## Configuration
```json
{"testFramework":"rescript-vitest-3","rules":{"test/prefer-hooks-in-order":true}}
```
Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations
Applies to recognized lifecycle hooks and their source order in supported suite scopes.
