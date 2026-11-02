# `jsx-a11y/aria-role`

Use a recognized concrete ARIA role.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Correct misspelled or unsupported role values, and prefer native semantic
elements where possible.

## Examples

### Incorrect
```rescript
let control = <div role="clickable" />
```

### Correct
```rescript
let control = <div role="button" />
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/aria-role":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; the recognized role model is finite and based on WAI-ARIA
roles, not runtime accessibility-tree computation.

The accepted role names are the rule's finite recognized role set. Dynamic
roles and spreads may be unknown; a recognized role does not ensure that the
element implements the role's required interaction behavior.
