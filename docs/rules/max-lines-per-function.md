# `max-lines-per-function`

Limit a function's physical source-line span.

- Category: `pedantic`
- Enabled by default: No
- Autofix: No

Use this policy to keep functions reviewable. Extract coherent operations rather
than compressing code just to satisfy a line count.

## Examples

These examples use `maxLinesPerFunction: 3`.

### Incorrect

```rescript
let increment = value => {
  let next = value + 1
  next
}
```

### Correct

```rescript
let increment = value => value + 1
```

## Configuration

```json
{
  "rules": {
    "max-lines-per-function": true
  },
  "maxLinesPerFunction": 3
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

`maxLinesPerFunction` is a nonnegative integer; the default is `50`.
Set the rule to `false` to disable it.

## Limitations

Counts physical lines from the beginning to the end of a function expression,
including blank lines and comments within that span. It is not a statement
count, complexity metric, or formatter width setting.

See the [policy boundaries](SYNTAX_RULES.md#policy-boundaries).
