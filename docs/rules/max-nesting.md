# `max-nesting`

Limit control-flow nesting depth.

- Category: `pedantic`
- Enabled by default: No
- Autofix: No

Deeply nested control flow is harder to follow. Simplify conditions or extract
a helper that represents a meaningful operation.

## Examples

These examples use `maxNesting: 1`.

### Incorrect

```rescript
let canRun = (enabled, ready) => if enabled {
  if ready {true} else {false}
} else {
  false
}
```

### Correct

```rescript
let canRun = (enabled, ready) => enabled && ready
```

## Configuration

```json
{
  "rules": {
    "max-nesting": true
  },
  "maxNesting": 1
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

`maxNesting` is a nonnegative integer; the default is `4`.
Set the rule to `false` to disable it.

## Limitations

Counts `if`, switch, try/catch, while, and for constructs. Else-if arms stay
at the same level; records, modules, and JSX layout do not add depth.
Functions start a fresh context. Only the first level beyond the limit is
reported in a nested region.
