# `jsx-a11y/aria-unsupported-elements`

Avoid ARIA roles and properties on metadata elements that do not support them.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

ARIA does not make metadata tags such as `meta` or `script` meaningful interface
elements. Put semantics on appropriate content instead.

## Examples

### Incorrect
```rescript
let metadata = <meta ariaHidden=true />
```

### Correct
```rescript
let metadata = <meta />
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/aria-unsupported-elements":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`. The check targets a fixed set of unsupported intrinsic
metadata tags.

See [JSX accessibility analysis boundaries](../EXTENDED_RULES.md#jsx-accessibility)
and [compiler-audited examples](../RULE_EXAMPLES.md#aria-unsupported-elements).
