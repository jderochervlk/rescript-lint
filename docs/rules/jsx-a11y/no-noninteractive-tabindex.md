# `jsx-a11y/no-noninteractive-tabindex`

Avoid placing noninteractive content in the keyboard tab order.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Use a native control when content is actionable. Reserve `tabIndex=0` for
elements with a meaningful keyboard interaction.

## Examples

### Incorrect
```rescript
let note = <div tabIndex=0> {React.string("Note")} </div>
```

### Correct
```rescript
let note = <div> {React.string("Note")} </div>
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/no-noninteractive-tabindex":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; detects known noninteractive semantics and nonnegative
static tab indices. Dynamic values remain unknown.

See [JSX accessibility analysis boundaries](../EXTENDED_RULES.md#jsx-accessibility)
and [compiler-audited examples](../RULE_EXAMPLES.md#no-noninteractive-tabindex).
