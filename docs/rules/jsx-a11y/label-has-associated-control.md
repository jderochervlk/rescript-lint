# `jsx-a11y/label-has-associated-control`

Associate each form label with a control.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Connect a label with `htmlFor` and a matching control `id`, or nest the
labelable control inside the label.

## Examples

### Incorrect
```rescript
let field = <> <label> {React.string("Email")} </label> <input id="email" /> </>
```

### Correct
```rescript
let field = <> <label htmlFor="email"> {React.string("Email")} </label> <input id="email" /> </>
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/label-has-associated-control":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`. Static sibling/nested JSX is inspected; dynamic IDs,
spreads, and component-rendered controls cannot always be resolved.

The rule inspects statically visible labelable elements, siblings, and nested
JSX. It cannot always resolve dynamic IDs, spreads, or controls rendered by
components; verify the association in the browser.
