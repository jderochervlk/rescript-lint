# `preferred-type-syntax`

Prefers the builtin `dict<a>` type syntax to the standard `Dict.t<a>` alias.

- Category: `style`
- Enabled by default: No
- Autofix: No

The rule recognizes the standard dictionary type through standard aliases and opens, including annotations in `.resi` files. It does not flag a project-local type with the same spelling, and it does not rewrite types automatically.

## Examples

### Incorrect

```rescript
type values = Dict.t<int>
```

### Correct

```rescript
type values = dict<int>
```

## Configuration

Set the rule to `true` to enable it; `false` disables it. There are no rule-specific options.

```json
{
  "rules": {
    "preferred-type-syntax": true
  }
}
```

Run `npx rescript-lint --config rescript-lint.json src/Main.res`.

See [Additional Opt-in Policies](POLICY_EXPANSION.md#additional-opt-in-policies).
