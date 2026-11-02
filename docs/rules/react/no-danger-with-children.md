# `react/no-danger-with-children`

Do not provide both raw HTML and JSX children to one element.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

These are conflicting content sources; choose one deliberately. Raw HTML also requires careful sanitization.

## Examples

### Incorrect

```rescript
let content = <div dangerouslySetInnerHTML={{"__html": html}}>
  {React.string("Fallback")}
</div>
```

### Correct

```rescript
let content = <div dangerouslySetInnerHTML={{"__html": html}} />
```

## Configuration

`false` disables this rule.

```json
{"jsxRuntime":"react-dom","rules":{"react/no-danger-with-children":true}}
```

Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

The check uses statically visible intrinsic JSX content and props; unknown spreads cannot be resolved. An absent React adapter is an analysis error.

See [React examples](../RULE_EXAMPLES.md#react-rules) and [React boundaries](../EXTENDED_RULES.md#react-rules).
