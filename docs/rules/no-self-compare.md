# `no-self-compare`

Report comparisons of a stable value with itself.

- Category: `pedantic`
- Enabled by default: No
- Autofix: No

This check is based on resolved lexical identity and known value semantics, not merely identical text. It does not claim every repeated-looking expression is safe to remove.

## Examples

### Incorrect

```rescript
let unchanged = (currentVersion: int, previousVersion: int) =>
  currentVersion === currentVersion
```

### Correct

```rescript
let unchanged = (currentVersion: int, previousVersion: int) =>
  currentVersion === previousVersion
```

## Configuration

```json
{
  "rules": {
    "no-self-compare": true
  }
}
```

Set the value to `false` to disable this rule.
Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Checks supported structural and physical comparison operators using resolved
lexical identity. Known float self-comparisons are also reported; use a dedicated
NaN predicate when that is the intended test. Missing required type information
can fail analysis rather than establish that a comparison is safe to remove.

See [semantic rule boundaries](EXTENDED_RULES.md#semantic-rules) and [audited examples](RULE_EXAMPLES.md#no-self-compare).
