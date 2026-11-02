# `jsx-a11y/no-access-key`

Avoid `accessKey` shortcuts that can conflict with platform and assistive shortcuts.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Do not assign global keyboard shortcuts through this attribute; users may be
unable to predict or override collisions.

## Examples

### Incorrect
```rescript
let save = <button accessKey="s"> {React.string("Save")} </button>
```

### Correct
```rescript
let save = <button> {React.string("Save")} </button>
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/no-access-key":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; reports presence of the statically recognized property.

See [JSX accessibility analysis boundaries](../EXTENDED_RULES.md#jsx-accessibility)
and [compiler-audited examples](../RULE_EXAMPLES.md#no-access-key).
