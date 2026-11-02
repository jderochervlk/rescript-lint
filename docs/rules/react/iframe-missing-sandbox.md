# `react/iframe-missing-sandbox`

Require a sandbox declaration on iframes.

- Category: `suspicious`
- Enabled by default: No
- Autofix: No

Sandboxing limits capabilities granted to embedded content. Select only the tokens required by the embedded application.

## Examples

### Incorrect

```rescript
let preview = <iframe src=previewUrl title="Preview" />
```

### Correct

```rescript
let preview = <iframe src=previewUrl title="Preview" sandbox="allow-scripts" />
```

## Configuration

`false` disables this rule.

```json
{"jsxRuntime":"react-dom","rules":{"react/iframe-missing-sandbox":true}}
```

Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Checks presence, not whether the selected sandbox permissions are safe. Missing JSX adapter is an analysis error.
