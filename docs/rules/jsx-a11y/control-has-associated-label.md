# `jsx-a11y/control-has-associated-label`

Give visible form controls an accessible name.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Use visible content, an associated label, or an accessible-name prop so users
can understand a control's purpose.

## Examples

### Incorrect
```rescript
let input = <input type_="search" />
```

### Correct
```rescript
let input = <input type_="search" ariaLabel="Search" />
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/control-has-associated-label":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; associated labels are recognized only in the statically
available JSX file context. Dynamic names may remain unknown.

See [JSX accessibility analysis boundaries](../EXTENDED_RULES.md#jsx-accessibility)
and [compiler-audited examples](../RULE_EXAMPLES.md#control-has-associated-label).
