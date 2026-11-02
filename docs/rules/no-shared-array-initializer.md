# `no-shared-array-initializer`

Flags supported array construction forms that place the same mutable initializer value in multiple slots.

- Category: `suspicious`
- Enabled by default: No
- Autofix: No

When each element must be independent, construct a fresh value for each index.

## Examples

### Incorrect

```rescript
type item = {mutable selected: bool}
let items = Array.make(~length=3, {selected: false})
```

### Correct

```rescript
type item = {mutable selected: bool}
let items = Array.fromInitializer(~length=3, _ => {selected: false})
```

## Configuration

```json
{
  "rules": {
    "no-shared-array-initializer": true
  }
}
```

Set the value to `false` to disable this rule. Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

The check is limited to recognized array constructors and initializer forms. It does not prove arbitrary values immutable.

See [semantic rule boundaries](EXTENDED_RULES.md#semantic-rules) and [audited examples](RULE_EXAMPLES.md#no-shared-array-initializer).
