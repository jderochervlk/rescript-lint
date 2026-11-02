# `no-unnecessary-template`

Flags a complete, untagged template literal that contains no interpolation.

- Category: `style`
- Enabled by default: No
- Autofix: No

Use an ordinary string when template functionality is not needed. Interpolated, tagged, and JSON templates are outside this rule's scope.

## Examples

### Incorrect

```rescript
let greeting = `hello`
```

### Correct

```rescript
let greeting = "hello"
```

## Configuration

Set the rule to `true` to enable it; `false` disables it. There are no rule-specific options.

```json
{
  "rules": {
    "no-unnecessary-template": true
  }
}
```

Run `npx rescript-lint --config rescript-lint.json src/Main.res`.

See [Additional Opt-in Policies](POLICY_EXPANSION.md#additional-opt-in-policies).
