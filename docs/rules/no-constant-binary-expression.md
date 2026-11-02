# `no-constant-binary-expression`

Report binary expressions whose result is fixed.

- Category: `correctness`
- Enabled by default: Yes
- Autofix: No

An expression such as `ready && false` cannot communicate a runtime decision.
Check whether an operand or operator was written incorrectly.

## Examples

### Incorrect

```rescript
let canRun = ready => ready && false
```

### Correct

```rescript
let canRun = (ready, enabled) => ready && enabled
```

## Configuration

```json
{
  "rules": {
    "no-constant-binary-expression": true
  }
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

Set the rule to `false` to disable it.

## Limitations

Uses conservative boolean and supported literal-comparison evaluation, not
general constant propagation. A fixed expression in condition position may
also receive [`no-constant-condition`](no-constant-condition.md).
Reporting a fixed result does not establish that evaluating the expression
is unnecessary: `read() && false` still evaluates `read()`.
