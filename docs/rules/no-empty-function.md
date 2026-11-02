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

See the [policy boundaries](SYNTAX_RULES.md#policy-boundaries).
