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

Recognizes a specific single-parameter, two-arm, unguarded list recursion
equivalent to `List.map`: the empty list returns an empty list, while the cons
arm transforms the head with a known-pure expression and recurses directly on
the tail. This is not a general detector for every standard combinator or every
recursive traversal.
