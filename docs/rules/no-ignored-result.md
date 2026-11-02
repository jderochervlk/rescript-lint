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

Checks wildcard bindings and resolved standard or result-specific `ignore`
calls when the discarded value is known to be a result. Missing required type
information fails analysis. Storing the result in a named binding is not
reported and does not prove that its error case will eventually be handled.
