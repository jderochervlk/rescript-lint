# `react/jsx-no-target-blank`

Protect links opened in a new browsing context.

- Category: `pedantic`
- Enabled by default: No
- Autofix: No

For links with `target="_blank"`, declare a protective `rel` value such as `noopener noreferrer`.

## Examples

### Incorrect

```rescript
let docs = <a href=externalUrl target="_blank"> {React.string("Docs")} </a>
```

### Correct

```rescript
let docs = <a href=externalUrl target="_blank" rel="noopener noreferrer">
  {React.string("Docs")}
</a>
```

## Configuration

`false` disables this rule.

```json
{"jsxRuntime":"react-dom","rules":{"react/jsx-no-target-blank":true}}
```

Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Static target and rel props are analyzed; dynamic values may remain unknown. Missing adapter configuration is an analysis error.
