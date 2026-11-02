# `no-optional-some`

Disallows explicitly wrapping a value in `Some` when passing it to a direct optional labeled argument.

- Category: `style`
- Enabled by default: No
- Autofix: No

Pass the value directly to the optional argument. Detection is limited to the builtin option constructor resolved in scope; `None`, unrelated `Some` constructors, mandatory arguments, and arbitrary option values are not reported.

## Examples

### Incorrect

```rescript
let consume = (~value=?, ()) => value
let result = consume(~value=?Some(1), ())
```

### Correct

```rescript
let consume = (~value=?, ()) => value
let result = consume(~value=1, ())
```

## Configuration

Set the rule to `true` to enable it; `false` disables it. There are no rule-specific options.

```json
{
  "rules": {
    "no-optional-some": true
  }
}
```

Run `npx rescript-lint --config rescript-lint.json src/Main.res`.
