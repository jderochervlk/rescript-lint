# `jsx-a11y/no-noninteractive-element-interactions`

Use an interactive element for interaction handlers.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Do not attach user interaction to a generic noninteractive element without
semantics. Choose a button or link for actions and navigation.

## Examples

### Incorrect
```rescript
let save = <div onClick={_ => saveForm()}> {React.string("Save")} </div>
```

### Correct
```rescript
let save = <button onClick={_ => saveForm()}> {React.string("Save")} </button>
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/no-noninteractive-element-interactions":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`; checks known handlers and semantics but cannot verify
runtime behavior. Explicit roles affect this rule's decision.

See [JSX accessibility analysis boundaries](../EXTENDED_RULES.md#jsx-accessibility)
and [compiler-audited examples](../RULE_EXAMPLES.md#no-noninteractive-element-interactions).
