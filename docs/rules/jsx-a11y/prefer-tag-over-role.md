# `jsx-a11y/prefer-tag-over-role`

Prefer a native HTML element when it provides the requested role.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Native elements provide established semantics, focus behavior, and interaction
contracts that a role attribute alone does not recreate.

## Examples

### Incorrect
```rescript
let save = <div role="button" tabIndex=0> {React.string("Save")} </div>
```

### Correct
```rescript
let save = <button> {React.string("Save")} </button>
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/prefer-tag-over-role":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; it recommends known native equivalents for recognized
explicit roles and does not assess the whole interaction implementation.

The rule recommends known native equivalents for recognized static roles; it
does not assess the complete interaction implementation or custom elements.
