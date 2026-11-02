# `no-negated-condition`

Flags a direct negation used as the condition of an `if` expression with both branches.

- Category: `pedantic`
- Enabled by default: No
- Autofix: No

Prefer a positive condition and exchange the branches for easier reading. The rule detects syntactic `!`, not a call to a function named `not`; an `if` without an `else` is not reported.

## Examples

### Incorrect

```rescript
let choose = ready => if !ready {1} else {2}
```

### Correct

```rescript
let choose = ready => if ready {2} else {1}
```

## Configuration

Set the rule to `true` to enable it; `false` disables it. There are no rule-specific options.

```json
{
  "rules": {
    "no-negated-condition": true
  }
}
```

Run `npx rescript-lint --config rescript-lint.json src/Main.res`.

See [Additional Opt-in Policies](POLICY_EXPANSION.md#additional-opt-in-policies).
