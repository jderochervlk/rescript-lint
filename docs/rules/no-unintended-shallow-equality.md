# `no-unintended-shallow-equality`

Flags physical equality used on known compound values where structural equality is more likely intended.

- Category: `suspicious`
- Enabled by default: No
- Autofix: No

ReScript's `===` tests identity rather than recursively comparing collection contents. Use it when identity is the intended question.

## Examples

### Incorrect

```rescript
let sameItems = (currentItems: array<int>, expectedItems: array<int>) =>
  currentItems === expectedItems
```

### Correct

```rescript
let sameItems = (currentItems: array<int>, expectedItems: array<int>) =>
  currentItems == expectedItems
```

## Configuration

```json
{
  "rules": {
    "no-unintended-shallow-equality": true
  }
}
```

Set the value to `false` to disable this rule.
Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

The rule relies on resolved known compound-value information; it is not a general type checker.

See [semantic rule boundaries](EXTENDED_RULES.md#semantic-rules) and [audited examples](RULE_EXAMPLES.md#no-unintended-shallow-equality).
