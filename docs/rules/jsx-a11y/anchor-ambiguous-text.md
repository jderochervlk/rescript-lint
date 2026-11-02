# `jsx-a11y/anchor-ambiguous-text`

Restrict vague link labels such as “click here” so the destination is clear.

- Category: `restriction`
- Enabled by default: No
- Autofix: No

This policy flags a finite set of ambiguous literal link texts. Prefer text that
identifies the destination or purpose.

## Examples

### Incorrect
```rescript
let link = <a href="/billing"> {React.string("Click here")} </a>
```

### Correct
```rescript
let link = <a href="/billing"> {React.string("View billing history")} </a>
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/anchor-ambiguous-text":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`. Detection is limited to recognized literal child text
(`click here`, `here`, `link`, `more`, `read more`, and `learn more`) and does
not evaluate dynamically composed accessible names.

See [JSX accessibility analysis boundaries](../EXTENDED_RULES.md#jsx-accessibility)
and [compiler-audited examples](../RULE_EXAMPLES.md#anchor-ambiguous-text).
