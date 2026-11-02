# `jsx-a11y/no-interactive-element-to-noninteractive-role`

Do not override native interactive semantics with a noninteractive role.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Keep a button a button. Removing its semantics can make an operable control
unavailable or confusing to assistive-technology users.

## Examples

### Incorrect
```rescript
let save = <button role="presentation"> {React.string("Save")} </button>
```

### Correct
```rescript
let save = <button> {React.string("Save")} </button>
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/no-interactive-element-to-noninteractive-role":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; it uses known intrinsic semantics and recognized role
metadata rather than computed browser semantics.

The check compares known intrinsic element semantics with recognized static
roles. Dynamic roles and custom-component output may be unknown.
