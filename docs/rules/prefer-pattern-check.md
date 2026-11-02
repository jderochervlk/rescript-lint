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

Checks structural `==`/`!=` comparisons against recursively literal,
payload-bearing list or ordinary variant shapes. Efficient empty-list and
`None` checks, payload-free constructors, and dynamic payloads are excluded.
It does not rewrite arbitrary equality comparisons.
