# `jsx-a11y/lang`

Use a valid language tag in `lang` attributes.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Language tags such as `en` or `en-US` help assistive technology pronounce
content correctly. Mark passages that differ from the document language.

## Examples

### Incorrect
```rescript
let quote = <blockquote lang="english" />
```

### Correct
```rescript
let quote = <blockquote lang="en" />
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/lang":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; validates static strings only and cannot determine the
actual language of arbitrary text.

See [JSX accessibility analysis boundaries](../EXTENDED_RULES.md#jsx-accessibility)
and [compiler-audited examples](../RULE_EXAMPLES.md#lang).
