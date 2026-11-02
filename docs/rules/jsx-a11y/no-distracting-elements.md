# `jsx-a11y/no-distracting-elements`

Avoid obsolete blinking or scrolling elements.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Replace `<marquee>` and `<blink>` with ordinary content or controlled,
user-initiated motion.

## Examples

### Incorrect
```rescript
let notice = <marquee> {React.string("Important update")} </marquee>
```

### Correct
```rescript
let notice = <p> {React.string("Important update")} </p>
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/no-distracting-elements":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; this check only targets the named intrinsic tags and is
not a general motion or animation audit.

See [JSX accessibility analysis boundaries](../EXTENDED_RULES.md#jsx-accessibility)
and [compiler-audited examples](../RULE_EXAMPLES.md#no-distracting-elements).
