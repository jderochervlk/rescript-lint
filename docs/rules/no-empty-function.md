# `no-empty-function`

Require literal unit-bodied no-op functions to be explicitly intentional.

- Category: `restriction`
- Enabled by default: No
- Autofix: No

An empty body can indicate unfinished implementation. If a no-op callback is
intentional, annotate its return type as `unit`.

## Examples

### Incorrect

```rescript
let onClose = () => ()
```

### Correct

```rescript
let onClose = (): unit => ()
```

When the callback is meant to perform work, implement that work instead of
marking the empty body intentional:

### Incorrect: implementing a callback

```rescript
let handleClick = (_track: string => unit) => ()
```

### Correct: implementing a callback

```rescript
let handleClick = (track: string => unit) => track("button_clicked")
```

## Configuration

```json
{
  "rules": {
    "no-empty-function": true
  }
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

Set the rule to `false` to disable it.

## Limitations

Only literal unit bodies are empty for this check. An empty record is a
meaningful value, not an empty function. Comments alone do not establish that
a unit-bodied function is intentional; use the explicit return annotation.
