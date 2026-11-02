# `no-single-case-switch`

Disallows a switch with one unguarded, irrefutable case.

- Category: `style`
- Enabled by default: No
- Autofix: No

An irrefutable wildcard or variable pattern matches every value, so the switch adds no decision. Refutable constructor patterns and guarded cases are not reported.

## Examples

### Incorrect

```rescript
let increment = value => switch value {| x => x + 1}
```

### Correct

```rescript
let increment = value => value + 1
```

## Configuration

Set the rule to `true` to enable it; `false` disables it. There are no rule-specific options.

```json
{
  "rules": {
    "no-single-case-switch": true
  }
}
```

Run `npx rescript-lint --config rescript-lint.json src/Main.res`.
