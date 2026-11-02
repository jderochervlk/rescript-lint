# `jsx-a11y/alt-text`

Require text alternatives for images and image-like content.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Supply a concise `alt` description for meaningful images. Decorative images
should use an empty `alt` value; this check primarily detects absent alternatives.

## Examples

### Incorrect
```rescript
let avatar = <img src="avatar.png" />
```

### Correct
```rescript
let avatar = <img src="avatar.png" alt="Profile photo" />
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/alt-text":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires the `react-dom` JSX adapter. Checks known intrinsic elements and static
props; dynamic props, spreads, and custom-component output may be unknown.

See [JSX accessibility analysis boundaries](../EXTENDED_RULES.md#jsx-accessibility)
and [compiler-audited examples](../RULE_EXAMPLES.md#alt-text).
