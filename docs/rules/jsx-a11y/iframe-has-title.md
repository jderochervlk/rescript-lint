# `jsx-a11y/iframe-has-title`

Give each frame a title that describes its embedded content.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Frame titles help users identify embedded browsing contexts without entering
them first.

## Examples

### Incorrect
```rescript
let map = <iframe src="/map" />
```

### Correct
```rescript
let map = <iframe src="/map" title="Office location" />
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/iframe-has-title":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; a nonempty title's accuracy cannot be judged statically.

See [JSX accessibility analysis boundaries](../EXTENDED_RULES.md#jsx-accessibility)
and [compiler-audited examples](../RULE_EXAMPLES.md#iframe-has-title).
