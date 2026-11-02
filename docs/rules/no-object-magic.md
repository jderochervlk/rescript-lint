# `no-object-magic`

Disallow unchecked casts through `Obj.magic` and its supported runtime aliases.

- Category: `correctness`
- Enabled by default: Yes
- Autofix: No

An unchecked cast bypasses the type system without validating the runtime value.
Use a checked conversion or model the data precisely.

## Examples

### Incorrect

```rescript
let parseId = text => Some((Obj.magic(text): int))
```

### Correct

```rescript
let parseId = text => Int.fromString(text)
```

The checked conversion returns `None` when the string is not an integer.

## Configuration

```json
{
  "rules": {
    "no-object-magic": true
  }
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

Set the rule to `false` to disable it.

## Limitations

The actual standard API is `Obj.magic`, not `Object.magic`; the rule keeps its
historical `no-object-magic` ID. It also recognizes the explicit compatibility
spellings `Primitive_object.magic` and `Primitive_object_extern.magic`.
References passed as values or captured through supported aliases are included.
Surrounding exception handling does not make an unchecked cast safe.

Custom `%identity` externals and arbitrary conversions are not covered.
