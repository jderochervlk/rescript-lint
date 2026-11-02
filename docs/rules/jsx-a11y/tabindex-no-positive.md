# `jsx-a11y/tabindex-no-positive`

Avoid positive `tabIndex` values that disrupt natural focus order.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Use DOM order for sequential navigation. `tabIndex=0` can include a custom
control in natural order; negative values are for programmatic focus only.

## Examples

### Incorrect
```rescript
let search = <input tabIndex=2 />
```

### Correct
```rescript
let search = <input tabIndex=0 />
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/tabindex-no-positive":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; checks statically known integer values greater than zero.

The rule checks statically known integer `tabIndex` values greater than zero;
dynamic values and the resulting page-wide focus order are not evaluated.
dynamic values and the resulting page-wide focus order are not evaluated.
