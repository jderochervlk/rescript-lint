# `jsx-a11y/role-supports-aria-props`

Use ARIA properties supported by the element's role.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

An unsupported or prohibited property can communicate the wrong state to
assistive technology. Check that the role actually owns the property.

## Examples

### Incorrect
```rescript
let article = <article role="article" ariaChecked=#"true" />
```

### Correct
```rescript
let article = <article role="article" />
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/role-supports-aria-props":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; validates explicit static ARIA props against recognized
role metadata, not dynamic prop spreads.

The rule validates explicit static ARIA props against recognized role metadata;
dynamic props and spreads may be unknown.
