# `jsx-a11y/role-has-required-aria-props`

Include required ARIA properties for the element's role.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Roles that require state or value information are incomplete without those
properties. Prefer native elements when available.

## Examples

### Incorrect
```rescript
let toggle = <div role="checkbox" tabIndex=0 />
```

### Correct
```rescript
let toggle = <div role="checkbox" ariaChecked=#"true" tabIndex=0 />
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/role-has-required-aria-props":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; validates required properties in the supported role model.
Dynamic props and unknown roles cannot establish completeness.

See [JSX accessibility analysis boundaries](../EXTENDED_RULES.md#jsx-accessibility)
and [compiler-audited examples](../RULE_EXAMPLES.md#role-has-required-aria-props).
