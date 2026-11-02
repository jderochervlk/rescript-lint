# `no-await-in-loop`

Reports await expressions in loops when the rule can establish that iterations are independent.

- Category: `perf`
- Enabled by default: No
- Autofix: No

Independent operations can often be started together and joined with `Promise.all`. Preserve sequential awaiting when later iterations depend on earlier results.

## Examples

### Incorrect

```rescript
let waitForAll = async () => {
  for _index in 0 to 3 {
    await Promise.resolve()
  }
}
```

### Correct

```rescript
let waitForAll = async () => {
  let _results = await [
    Promise.resolve(),
    Promise.resolve(),
    Promise.resolve(),
    Promise.resolve(),
  ]->Promise.all
  ()
}
```

## Configuration

```json
{
  "rules": {
    "no-await-in-loop": true
  }
}
```

Set the value to `false` to disable this rule.
Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Only loops whose iterations are provably or explicitly marked independent are reported. `@lint.independent` is a trust contract, not a fact verified by the linter; do not add it just to silence a finding.

See [semantic rule boundaries](EXTENDED_RULES.md#semantic-rules) and [audited examples](RULE_EXAMPLES.md#no-await-in-loop).
