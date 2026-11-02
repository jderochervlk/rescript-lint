# `jsx-a11y/anchor-has-content`

Require visible accessible content for links.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Provide descriptive text or another accessible name for each visible anchor.

## Examples

### Incorrect
```rescript
let link = <a href="/docs" />
```

### Correct
```rescript
let link = <a href="/docs"> {React.string("Documentation")} </a>
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/anchor-has-content":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; unknown dynamic children and custom components are not
proven to have accessible content.

See [JSX accessibility analysis boundaries](../EXTENDED_RULES.md#jsx-accessibility)
and [compiler-audited examples](../RULE_EXAMPLES.md#anchor-has-content).
