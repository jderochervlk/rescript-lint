# `prefer-standard-combinator`

Prefer a known standard combinator over a supported recursive collection implementation.

- Category: `style`
- Enabled by default: No
- Autofix: No

Standard combinators communicate common collection transformations clearly and avoid maintaining bespoke recursive traversal.

## Examples

### Incorrect

```rescript
let rec doubleAll = items => switch items {
| list{} => list{}
| list{head, ...tail} => list{head * 2, ...doubleAll(tail)}
}
```

### Correct

```rescript
let doubleAll = items => items->List.map(value => value * 2)
```

## Configuration

```json
{
  "rules": {
    "prefer-standard-combinator": true
  }
}
```

Set the value to `false` to disable this rule. Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Only supported recursive forms with proven combinator equivalence are reported; arbitrary recursion is not presumed replaceable.

See [semantic rule boundaries](EXTENDED_RULES.md#semantic-rules) and [audited examples](RULE_EXAMPLES.md#prefer-standard-combinator).
