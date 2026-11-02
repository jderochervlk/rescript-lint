# `react/rules-of-hooks`

Call React hooks only in supported top-level component and custom-hook execution contexts.

- Category: `pedantic`
- Enabled by default: Yes
- Autofix: No

Hooks must run consistently during render. This is a syntactic convention check:
it does not require `jsxRuntime`, execute components, or prove runtime call order.
Ordinary hooks must be called directly in supported component or custom-hook
bodies, not conditional branches, loops, ordinary callbacks, default arguments,
async functions, or exception-handling regions.

## Examples
### Incorrect
```rescript
@react.component
let make = (~enabled) => {
  if enabled {
    let _state = React.useState(() => false)
    ()
  }
  React.null
}
```
### Correct
```rescript
@react.component
let make = (~enabled) => {
  let _state = React.useState(() => false)
  React.null
}
```

## Configuration
```json
{"rules":{"react/rules-of-hooks":true}}
```
`false` disables it. Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations
Recognizes the fixed `use` followed by uppercase-letter/digit naming convention;
there is no configurable custom-hook list. Separately declared nested custom
hooks receive their own function context. Exactly bare `use` and `React.use`
may be conditional or inside loops, but still need valid function and exception
contexts. `Other.use` is not recognized as that special API.

There is no hook symbol/shadow resolution or complete control-flow analysis.
See the [full hooks contract](../RULES.md#reactrules-of-hooks) for aliases,
wrapper components, early exits, and unsupported higher-order patterns.
