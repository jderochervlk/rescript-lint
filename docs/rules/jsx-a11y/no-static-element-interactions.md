# `jsx-a11y/no-static-element-interactions`

Give interactive behavior suitable semantics rather than attaching it to static content.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Use a button for an action or a link for navigation. If a custom widget is
necessary, its role, focus, and keyboard behavior must be designed together.

## Examples

### Incorrect
```rescript
let menu = <span onClick={_ => openMenu()}> {React.string("Menu")} </span>
```

### Correct
```rescript
let menu = <button onClick={_ => openMenu()}> {React.string("Menu")} </button>
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/no-static-element-interactions":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; detects known interaction handlers on statically
classified elements, not complete widget behavior.

See [JSX accessibility analysis boundaries](../EXTENDED_RULES.md#jsx-accessibility)
and [compiler-audited examples](../RULE_EXAMPLES.md#no-static-element-interactions).
