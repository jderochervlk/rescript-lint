# `jsx-a11y/aria-activedescendant-has-tabindex`

Require an active-descendant owner to be keyboard focusable.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

When managing focus through `aria-activedescendant`, the owning widget must
itself be reachable by keyboard, commonly with `tabIndex=0`.

## Examples

### Incorrect
```rescript
let listbox = <div role="listbox" ariaActivedescendant="item-1" />
```

### Correct
```rescript
let listbox = <div role="listbox" ariaActivedescendant="item-1" tabIndex=0 />
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/aria-activedescendant-has-tabindex":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; it checks statically known focusability, not the complete
runtime keyboard interaction model.

The check uses the statically known role, `ariaActivedescendant`, and focusability
props. It does not verify that the referenced item exists or that the widget's
keyboard interaction and focus management work after rendering.
