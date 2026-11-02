# `jsx-a11y/interactive-supports-focus`

Make interactive-role elements keyboard focusable.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

An element assigned an interactive role and interaction handlers needs a
keyboard focus path. Prefer a native interactive element.

## Examples

### Incorrect
```rescript
let control = <div role="button" onClick={_ => submit()} />
```

### Correct
```rescript
let control = <div role="button" tabIndex=0 onClick={_ => submit()} />
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/interactive-supports-focus":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; `tabIndex` presence does not verify correct keyboard
activation or focus management.

The check uses known static roles, handlers, and focus props. A `tabIndex`
does not ensure keyboard activation, visible focus, or correct focus management.
