# `jsx-a11y/no-noninteractive-element-to-interactive-role`

Avoid assigning interactive roles to noninteractive semantic elements.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Do not turn structural content such as a list item into a button by role alone.
Place a native control inside it instead.

## Examples

### Incorrect
```rescript
let action = <li role="button"> {React.string("Remove")} </li>
```

### Correct
```rescript
let action = <li> <button> {React.string("Remove")} </button> </li>
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/no-noninteractive-element-to-interactive-role":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; the check compares known intrinsic semantics with the
finite recognized role model.

The check compares known intrinsic semantics with a finite set of recognized
roles. Dynamic roles and custom-component output may not be classifiable.
