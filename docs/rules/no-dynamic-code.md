# `no-dynamic-code`

Restricts recognized dynamic-code APIs and raw-JavaScript expressions, which can bypass static analysis and introduce injection risks.

- Category: `restriction`
- Enabled by default: No
- Autofix: No

Represent executable input as data and interpret it through a deliberately constrained, typed evaluator instead of evaluating source text.

## Examples

### Incorrect

```rescript
let calculate: string => int = %raw("code => eval(code)")
```

### Correct

```rescript
let calculate = expression => Expression.evaluate(expression)
```

## Configuration

```json
{
  "rules": {
    "no-dynamic-code": true
  }
}
```

Set the value to `false` to disable this rule. Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Checks executable `raw`, `bs.raw`, and `res.raw` extensions, plus calls resolved
to global `eval` or `Function`, including recognized FFI bindings. Ordinary
externals, scoped lookalikes, and annotation payloads are not blanket violations.
The absence of a finding does not establish the safety of arbitrary external
code.
