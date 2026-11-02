# `react/no-children-prop`

Pass child content as JSX children instead of an explicit `children` prop.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

The normal child syntax makes component structure clear and avoids competing sources of children.

## Examples

### Incorrect

```rescript
let panel = <Panel children={React.string("Settings")} />
```

### Correct

```rescript
let panel = <Panel> {React.string("Settings")} </Panel>
```

## Configuration

`false` disables this rule.

```json
{"jsxRuntime":"react-dom","rules":{"react/no-children-prop":true}}
```

Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Dynamic spreads are not treated as proof of an explicit children prop. Missing adapter metadata is an analysis error.

See [React examples](../RULE_EXAMPLES.md#react-rules) and [React boundaries](../EXTENDED_RULES.md#react-rules).
