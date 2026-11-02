# `jsx-a11y/no-aria-hidden-on-focusable`

Do not hide focusable elements from the accessibility tree.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

An element that keyboard users can reach must not be removed from what
screen-reader users perceive. Hide it visually and from focus together when
appropriate.

## Examples

### Incorrect
```rescript
let hidden = <button ariaHidden=true> {React.string("Hidden action")} </button>
```

### Correct
```rescript
let hidden = <button ariaHidden=false> {React.string("Hidden action")} </button>
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/no-aria-hidden-on-focusable":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; reports the combination of known `ariaHidden=true` and
statically known focusability, not focus behavior after rendering.

The rule reports statically known `ariaHidden=true` combined with known
focusability. Dynamic props and rendered focus behavior may be unknown; it is
not a general accessibility-tree audit.
