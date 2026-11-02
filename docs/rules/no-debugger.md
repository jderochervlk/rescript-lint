# `no-debugger`

Disallow executable `%debugger` expressions.

- Category: `correctness`
- Enabled by default: Yes
- Autofix: No

Remove debugger statements before committing application code.

## Examples

### Incorrect

```rescript
let inspect = value => {
  %debugger
  value
}
```

### Correct

```rescript
let inspect = value => value
```

## Configuration

```json
{
  "rules": {
    "no-debugger": true
  }
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

Set the rule to `false` to disable it.

## Limitations

Visits executable expressions, including nested functions and modules.
Text in strings/comments and annotation payloads is not executable code;
an attribute named `@debugger` is not a debugger expression.

See the [exception and debugger reference](SYNTAX_RULES.md#exception-and-debugger-boundaries).
