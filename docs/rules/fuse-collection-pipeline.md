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

Recognizes adjacent resolved `Array.map` followed by `Array.map`, or `List.map`
followed by `List.map`, when both callbacks are known pure. It does not combine
arbitrary filter/reduce pipelines or mixed collection families.

`@lint.pure` is an explicit trust contract, not a purity proof. Do not add it
merely to silence a finding.
