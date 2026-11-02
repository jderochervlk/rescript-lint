# `react/button-has-type`

Require an explicit button type.

- Category: `restriction`
- Enabled by default: No
- Autofix: No

An untyped HTML button inside a form submits by default. State the intended behavior with ReScript React's `type_` prop.

## Examples

### Incorrect

```rescript
let save = <button> {React.string("Save")} </button>
```

### Correct

```rescript
let save = <button type_="button"> {React.string("Save")} </button>
```

## Configuration

`false` disables this rule.

```json
{"jsxRuntime":"react-dom","rules":{"react/button-has-type":true}}
```

Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Only statically visible button attributes are checked. Missing JSX adapter configuration is an analysis error.
