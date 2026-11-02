# `no-useless-concat`

Avoid concatenating ordinary string literals or an empty string.

- Category: `suspicious`
- Enabled by default: No
- Autofix: No

Write adjacent literal text as one string. Remove an empty-string operand when
it is not needed.

## Examples

### Incorrect

```rescript
let greeting = "Hello, " ++ "world"
```

### Correct

```rescript
let greeting = "Hello, world"
```

## Configuration

```json
{
  "rules": {
    "no-useless-concat": true
  }
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

Set the rule to `false` to disable it.

## Limitations

Checks explicit `++` syntax with two ordinary string literals or an empty
literal operand. Template strings and character literals are excluded.
It does not reassociate mixed dynamic/literal concatenations.
