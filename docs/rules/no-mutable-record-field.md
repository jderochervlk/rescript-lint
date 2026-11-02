# `no-mutable-record-field`

Disallows declarations of mutable record fields.

- Category: `restriction`
- Enabled by default: No
- Autofix: No

Mutable fields permit in-place state changes. Prefer an immutable field and construct an updated record when changing state. The rule checks record declarations in implementation and interface files.

## Examples

### Incorrect

```rescript
type state = {mutable count: int}
```

### Correct

```rescript
type state = {count: int}
```

## Configuration

Set the rule to `true` to enable it; `false` disables it. There are no rule-specific options.

```json
{
  "rules": {
    "no-mutable-record-field": true
  }
}
```

Run `npx rescript-lint --config rescript-lint.json src/Main.res`.
