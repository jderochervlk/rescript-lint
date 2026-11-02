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

The rule checks a finite set of words in static `alt` text. It cannot judge
whether the alternative is accurate, useful, or appropriate for the image's
context.
