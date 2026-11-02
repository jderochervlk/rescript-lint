# `jsx-a11y/scope`

Use the `scope` attribute only on table header cells.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

The attribute identifies the rows or columns described by a table header; put
it on `<th>`, not ordinary data cells.

## Examples

### Incorrect
```rescript
let cell = <td scope="col"> {React.string("Name")} </td>
```

### Correct
```rescript
let heading = <th scope="col"> {React.string("Name")} </th>
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/scope":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; this check only rejects a statically present `scope` on
non-`th` elements.

See [JSX accessibility analysis boundaries](../EXTENDED_RULES.md#jsx-accessibility)
and [compiler-audited examples](../RULE_EXAMPLES.md#scope).
