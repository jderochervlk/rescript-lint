# `no-redundant-mutual-recursion`

Reports recursive declaration groups whose members do not form the corresponding recursive dependency cycle.

- Category: `style`
- Enabled by default: No
- Autofix: No

Declare independent functions separately; reserve a mutual-recursion group for functions that actually depend on one another recursively.

## Examples

### Incorrect

```rescript
let rec increment = value => value + 1
and double = value => value * 2
```

### Correct

```rescript
let increment = value => value + 1
let double = value => value * 2
```

## Configuration

```json
{
  "rules": {
    "no-redundant-mutual-recursion": true
  }
}
```

Set the value to `false` to disable this rule. Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

The rule analyzes recognized declaration references and recursion relationships; it does not rewrite function groups.

See [semantic rule boundaries](EXTENDED_RULES.md#semantic-rules) and [audited examples](RULE_EXAMPLES.md#no-redundant-mutual-recursion).
