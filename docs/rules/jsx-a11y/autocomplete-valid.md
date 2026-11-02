# `jsx-a11y/autocomplete-valid`

Use valid HTML autocomplete tokens on form controls.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Use standardized tokens such as `email` to help browsers and assistive
technology identify the expected value.

## Examples

### Incorrect
```rescript
let input = <input autoComplete="electronic-mail" />
```

### Correct
```rescript
let input = <input autoComplete="email" />
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/autocomplete-valid":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; validates static `autoComplete` strings on input, select,
and textarea, not dynamically generated values.

See [JSX accessibility analysis boundaries](../EXTENDED_RULES.md#jsx-accessibility)
and [compiler-audited examples](../RULE_EXAMPLES.md#autocomplete-valid).
