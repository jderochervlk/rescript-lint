# `max-params`

Limit the number of declared function parameters.

- Category: `style`
- Enabled by default: No
- Autofix: No

Many positional arguments are easy to confuse. Group related data in a named
record when that makes the function's interface clearer.

## Examples

These examples use `maxParams: 2`.

### Incorrect

```rescript
let volume = (width, height, depth) => width * height * depth
```

### Correct

```rescript
type size = {width: int, height: int, depth: int}
let volume = size => size.width * size.height * size.depth
```

## Configuration

```json
{
  "rules": {
    "max-params": true
  },
  "maxParams": 2
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

`maxParams` is a nonnegative integer; the default is `5`.
Set the rule to `false` to disable it.

## Limitations

Labeled and optional parameters count. The unit placeholder in `() => ...`
counts as zero parameters. One multi-parameter function is checked once;
returned functions and default callbacks are checked separately.

See the [policy boundaries](SYNTAX_RULES.md#policy-boundaries).
