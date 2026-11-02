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

Only counting `for` loops whose entire unwrapped body is one direct await are
checked. The awaited call must resolve to `Promise.resolve` with a primitive
payload, or to a callee annotated `@lint.independent`; its arguments must be
known pure. Statically empty loops are exempt. General `while` loops and
multi-statement loop bodies are not analyzed for independence.

`@lint.independent` is an explicit trust contract, not a fact verified by the
linter. Do not add it merely to silence a finding.
