# `jsx-a11y/no-redundant-roles`

Omit an explicit role that repeats an element's native role.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Native elements already expose their semantics; redundant roles add noise and
can become misleading if markup changes.

## Examples

### Incorrect
```rescript
let save = <button role="button"> {React.string("Save")} </button>
```

### Correct
```rescript
let save = <button> {React.string("Save")} </button>
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/no-redundant-roles":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; compares explicit roles to statically known implicit
roles.

The check compares explicit static roles with known implicit roles on intrinsic
elements; dynamic roles and custom-component semantics may be unknown.
