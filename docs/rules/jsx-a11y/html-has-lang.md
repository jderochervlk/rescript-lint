# `jsx-a11y/html-has-lang`

Declare the primary language on the document's `html` element.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Set the document language so assistive technology can select appropriate
pronunciation and language processing.

## Examples

### Incorrect
```rescript
let page = <html> <body /> </html>
```

### Correct
```rescript
let page = <html lang="en"> <body /> </html>
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/html-has-lang":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; the check reports an absent or empty static `lang`
attribute and does not infer locale from application state.

See [JSX accessibility analysis boundaries](../EXTENDED_RULES.md#jsx-accessibility)
and [compiler-audited examples](../RULE_EXAMPLES.md#html-has-lang).
