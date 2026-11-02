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

Checks resolved `Array.make` calls with a fresh array literal or known
mutable-record expression passed directly as the initializer. A literal length
of at most one is exempt. Existing named mutable values and arbitrary allocation
functions are outside this detection subset; a nonfinding does not prove that
the initializer is immutable.
