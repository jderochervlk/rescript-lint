# `jsx-a11y/img-redundant-alt`

Avoid repeating “image,” “picture,” or “photo” in image alternative text.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Describe the meaningful subject directly; screen readers already identify the
element as an image.

## Examples

### Incorrect
```rescript
let logo = <img src="logo.png" alt="Image of the company logo" />
```

### Correct
```rescript
let logo = <img src="logo.png" alt="Acme" />
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/img-redundant-alt":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`. Checks a small set of words in static alt text, not
whether the description is otherwise suitable.

See [JSX accessibility analysis boundaries](../EXTENDED_RULES.md#jsx-accessibility)
and [compiler-audited examples](../RULE_EXAMPLES.md#img-redundant-alt).
