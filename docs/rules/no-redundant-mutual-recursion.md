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

Checks recursive groups of at least two bindings and requires their declaration
dependencies to form one mutually reachable component. A single unnecessary
`rec` binding is not this rule's target. It does not rewrite function groups.
