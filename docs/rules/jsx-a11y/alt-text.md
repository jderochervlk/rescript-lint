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

This check examines known intrinsic image elements and static `alt` props.
Dynamic values, spreads, and custom-component output may be unknown. It cannot
judge whether text is a suitable alternative; verify image alternatives in the
rendered interface.
