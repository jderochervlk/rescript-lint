# `prefer-pattern-check`

Prefers pattern matching for supported constructor-shape checks over equality against a constructed value.

- Category: `perf`
- Enabled by default: No
- Autofix: No

Pattern matching expresses the shape being tested directly. Efficient payload-free checks are exempt.

## Examples

### Incorrect

```rescript
let isPair = (items: list<int>) => items == list{1, 2}
```

### Correct

```rescript
let isPair = (items: list<int>) => switch items {
| list{1, 2} => true
| _ => false
}
```

## Configuration

```json
{
  "rules": {
    "prefer-pattern-check": true
  }
}
```

Set the value to `false` to disable this rule. Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

The check recognizes supported constructor comparisons; it does not rewrite arbitrary equality checks.

See [semantic rule boundaries](EXTENDED_RULES.md#semantic-rules) and [audited examples](RULE_EXAMPLES.md#prefer-pattern-check).
