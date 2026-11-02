# `prefer-empty-check`

Prefers a direct empty-collection check over supported collection-size comparisons against zero.

- Category: `perf`
- Enabled by default: No
- Autofix: No

Use a shape check that directly communicates that the collection has no elements.

## Examples

### Incorrect

```rescript
let empty = items->List.length == 0
```

### Correct

```rescript
let empty = switch items {
| list{} => true
| list{_, ..._} => false
}
```

## Configuration

```json
{
  "rules": {
    "prefer-empty-check": true
  }
}
```

Set the value to `false` to disable this rule. Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Recognizes resolved `List.length`, `Array.length`, and `String.length` in
supported empty/nonempty comparisons against zero or one, including reversed
operands. Use list matching or the corresponding array/string empty check.
Arbitrary size APIs and other numeric thresholds are not covered.
