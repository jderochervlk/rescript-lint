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

Checks `===` and `!==` on known compound values, not primitive or payload-free
values indiscriminately. If reference identity is intentional, mark the
comparison explicitly, for example `@lint.identity (left === right)`.
Missing required type information can fail analysis. This is bounded source
inference, not a general type checker.
