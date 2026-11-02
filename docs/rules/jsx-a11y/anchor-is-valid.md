# `jsx-a11y/anchor-is-valid`

Use anchors for navigation and buttons for actions.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

An anchor should have a meaningful navigable `href`; an event handler alone does
not turn it into a link.

## Examples

### Incorrect
```rescript
let link = <a onClick={_ => openHelp()}> {React.string("Help")} </a>
```

### Correct
```rescript
let link = <a href="/help"> {React.string("Help")} </a>
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/anchor-is-valid":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`. Static source inspection cannot establish runtime URL
behavior for dynamic values.

The rule checks statically visible anchor attributes; it cannot establish
runtime URL behavior for dynamic values or whether the destination is useful.
