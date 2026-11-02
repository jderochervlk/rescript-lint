# `no-obj-external`

Disallows external declarations annotated with `@obj` or legacy `@bs.obj`.

- Category: `restriction`
- Enabled by default: No
- Autofix: No

This policy flags object-construction FFI declarations in implementation and interface files. Prefer a ReScript record or object expression where possible. It is an FFI policy, not a claim that every external is unsafe.

## Examples

### Incorrect

```rescript
@obj external make: (~name: string) => {"name": string} = ""
```

### Correct

```rescript
let make = (~name: string) => {"name": name}
```

## Configuration

Set the rule to `true` to enable it; `false` disables it. There are no rule-specific options.

```json
{
  "rules": {
    "no-obj-external": true
  }
}
```

Run `npx rescript-lint --config rescript-lint.json src/Main.res`.

## Limitations

The rule only detects `@obj` and `@bs.obj` on external declarations.
