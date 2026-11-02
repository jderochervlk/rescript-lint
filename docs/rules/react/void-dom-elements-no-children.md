# `react/void-dom-elements-no-children`

Prevent children or raw HTML on void DOM elements.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Void elements such as `img` cannot contain child content. Keep their information in supported attributes such as `alt`.

## Examples

### Incorrect

```rescript
let image = <img src="logo.png"> {React.string("Acme")} </img>
```

### Correct

```rescript
let image = <img src="logo.png" alt="Acme" />
```

## Configuration

`false` disables this rule.

```json
{"jsxRuntime":"react-dom","rules":{"react/void-dom-elements-no-children":true}}
```

Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Checks statically known void intrinsic tags; custom components are not classified as DOM void elements. Missing adapter metadata is an analysis error.
