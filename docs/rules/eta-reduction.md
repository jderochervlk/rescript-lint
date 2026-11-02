# `eta-reduction`

Prefers a direct function reference over a full-arity wrapper that only forwards its arguments.

- Category: `style`
- Enabled by default: No
- Autofix: No

The direct reference is shorter and avoids an unnecessary forwarding function.

## Examples

### Incorrect

```rescript
let parse = text => Int.fromString(text)
```

### Correct

```rescript
let parse = Int.fromString
```

## Configuration

```json
{
  "rules": {
    "eta-reduction": true
  }
}
```

Set the value to `false` to disable this rule. Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Reports only when full arity, labels, attributes, and semantics are provably equivalent; wrappers that narrow or transform behavior are retained.
