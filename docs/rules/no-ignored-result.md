# `no-ignored-result`

Reports known `Result` values discarded without handling their success and error cases.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Match the result and decide how each outcome should affect the surrounding operation.

## Examples

### Incorrect

```rescript
let validate = name => if name == "" {Error("Missing name")} else {Ok(name)}

let update = name => {
  validate(name)->ignore
  Ok(String.trim(name))
}
```

### Correct

```rescript
let validate = name => if name == "" {Error("Missing name")} else {Ok(name)}

let update = name => switch validate(name) {
| Ok(validName) => Ok(String.trim(validName))
| Error(error) => Error(error)
}
```

## Configuration

```json
{
  "rules": {
    "no-ignored-result": true
  }
}
```

Set the value to `false` to disable this rule.
Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Only known result values are covered. Other return types or effects require their own handling policy.

See [semantic rule boundaries](EXTENDED_RULES.md#semantic-rules) and [audited examples](RULE_EXAMPLES.md#no-ignored-result).
