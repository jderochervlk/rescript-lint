# `no-accumulating-concat`

Report supported reduce callbacks that repeatedly concatenate onto a growing string.

- Category: `perf`
- Enabled by default: No
- Autofix: No

Prefer a joining operation when it expresses the intended aggregation directly.

## Examples

### Incorrect

```rescript
let text = (parts: array<string>) =>
  parts->Array.reduce("", (acc, part) => acc ++ part)
```

### Correct

```rescript
let text = (parts: array<string>) => parts->Array.join("")
```

## Configuration

```json
{
  "rules": {
    "no-accumulating-concat": true
  }
}
```

Set the value to `false` to disable this rule.
Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Recognizes supported inline `Array.reduce` and `List.reduce` callbacks using
`++` with the accumulator on the left. It does not analyze arbitrary recursive
accumulation, named reducer callbacks, or every collection type.
