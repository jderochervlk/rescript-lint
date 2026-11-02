# `max-lines`

Limits the number of physical lines in a `.res` or `.resi` file.

- Category: `pedantic`
- Enabled by default: No
- Autofix: No

Comments and blank lines count. A final newline does not add another line; an empty file has zero lines. Set `maxLines` to a nonnegative integer; the default threshold is 300. Setting the threshold does not enable this rule.

## Examples

### Incorrect

With `maxLines` set to `3`, this four-line file exceeds the limit:

```rescript
let one = 1
let two = 2
let three = 3
let four = 4
```

### Correct

```rescript
let one = 1
let two = 2
let three = 3
```

## Configuration

Set the rule to `true` to enable it; `false` disables it. `maxLines` is the supported limit option and accepts zero or greater.

```json
{
  "rules": {
    "max-lines": true
  },
  "maxLines": 3
}
```

Run `npx rescript-lint --config rescript-lint.json src/Main.res`.

See [Additional Opt-in Policies](POLICY_EXPANSION.md#additional-opt-in-policies).
