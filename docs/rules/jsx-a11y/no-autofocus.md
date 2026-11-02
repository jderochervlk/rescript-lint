# `jsx-a11y/no-autofocus`

Avoid moving focus automatically on page or component load.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Automatic focus can disorient users and unexpectedly move their reading
position. Move focus only in response to an intentional user action.

## Examples

### Incorrect
```rescript
let search = <input autoFocus=true />
```

### Correct
```rescript
let search = <input />
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/no-autofocus":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; checks the statically true autofocus prop.

See [JSX accessibility analysis boundaries](../EXTENDED_RULES.md#jsx-accessibility)
and [compiler-audited examples](../RULE_EXAMPLES.md#no-autofocus).
