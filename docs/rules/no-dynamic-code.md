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

The rule recognizes known dynamic-code APIs and raw-JavaScript expressions; it cannot establish the safety of arbitrary external code.

See [semantic rule boundaries](EXTENDED_RULES.md#semantic-rules) and [audited examples](RULE_EXAMPLES.md#no-dynamic-code).
