# `jsx-a11y/heading-has-content`

Require visible accessible content inside headings.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Headings provide document structure; give each visible heading meaningful text.

## Examples

### Incorrect
```rescript
let heading = <h2 />
```

### Correct
```rescript
let heading = <h2> {React.string("Account settings")} </h2>
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/heading-has-content":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; unresolved dynamic children and custom-component output
cannot be confirmed as meaningful content.

The check detects known static children; it cannot establish meaningful text
from dynamic children or custom-component output.
