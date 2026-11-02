# `no-constant-condition`

Report conditions whose boolean result is statically fixed.

- Category: `correctness`
- Enabled by default: Yes
- Autofix: No

A constant condition can make a branch unreachable or a loop accidental.
Use the intended runtime condition, or remove the unnecessary control flow.

## Examples

### Incorrect

```rescript
let label = if true {"Ready"} else {"Waiting"}
```

### Correct

```rescript
let label = ready => if ready {"Ready"} else {"Waiting"}
```

## Configuration

```json
{
  "rules": {
    "no-constant-condition": true
  }
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

Set the rule to `false` to disable it.

## Limitations

Checks `if`, `while`, and switch guards using conservative literal/boolean
folding. It does not infer the values of bindings or prove function purity.
A fixed binary condition can also trigger
[`no-constant-binary-expression`](no-constant-binary-expression.md).
No fix is offered because discarding an expression can discard effects.

See the [control-flow contract](RULES.md#control-flow-rules).
