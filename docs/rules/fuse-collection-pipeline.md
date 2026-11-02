# `fuse-collection-pipeline`

Identifies supported adjacent collection transformations whose callbacks are known pure and can be combined into fewer passes.

- Category: `perf`
- Enabled by default: No
- Autofix: No

Combining stages may avoid intermediate collections. Keep separate stages when their sequencing or effects are meaningful.

## Examples

### Incorrect

```rescript
let transformed = values => values->Array.map(value => value + 1)->Array.map(value => value * 2)
```

### Correct

```rescript
let transformed = values => values->Array.map(value => (value + 1) * 2)
```

## Configuration

```json
{
  "rules": {
    "fuse-collection-pipeline": true
  }
}
```

Set the value to `false` to disable this rule. Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Only supported adjacent stages with known-pure callbacks are reported. `@lint.pure` is an explicit trust contract, not a purity proof; do not add it merely to silence a warning.

See [semantic rule boundaries](EXTENDED_RULES.md#semantic-rules) and [audited examples](RULE_EXAMPLES.md#fuse-collection-pipeline).
