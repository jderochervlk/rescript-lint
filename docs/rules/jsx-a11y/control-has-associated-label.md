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

The rule recognizes accessible-name props and associations visible in the
static JSX file context. Dynamic names and component-rendered labels may be
unknown; verify the computed name in the rendered interface.
