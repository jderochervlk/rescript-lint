# `jsx-a11y/click-events-have-key-events`

Provide keyboard activation when a non-native element handles clicks.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Prefer native buttons and links, which already provide expected keyboard
behavior, over recreating controls on generic elements.

## Examples

### Incorrect
```rescript
let control = <div onClick={_ => submit()}> {React.string("Submit")} </div>
```

### Correct
```rescript
let control = <button onClick={_ => submit()}> {React.string("Submit")} </button>
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/click-events-have-key-events":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`. Static handler checks do not prove that keyboard handlers
activate the same behavior as the click handler.

The rule detects known static event-handler presence; it cannot prove keyboard
handlers perform the same action, that the element is focusable, or that the
interaction works for users.
