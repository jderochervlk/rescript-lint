# `jsx-a11y/mouse-events-have-key-events`

Pair mouse enter and leave behavior with focus and blur behavior.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Ensure hover-only information or behavior is also available to keyboard users.
For an action, prefer a native button or link.

## Examples

### Incorrect
```rescript
let help = <div onMouseOver={_ => showHelp()} />
```

### Correct
```rescript
let help = <div onMouseOver={_ => showHelp()} onFocus={_ => showHelp()} />
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/mouse-events-have-key-events":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; matching handler presence does not establish equivalent
behavior or correct focusability.

The rule checks for known paired handler presence only. It does not prove
equivalent behavior or that the element is keyboard focusable.
