# `simplify-boolean-expression`

Prefer direct boolean expressions over redundant boolean syntax.

- Category: `style`
- Enabled by default: No
- Autofix: No

Use a boolean value directly instead of comparing it with a boolean literal or
returning `true` and `false` from an identity conditional.

## Examples

### Incorrect

```rescript
let visible = ready => if ready {true} else {false}
```

### Correct

```rescript
let visible = ready => ready
```

## Configuration

```json
{
  "rules": {
    "simplify-boolean-expression": true
  }
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

Set the rule to `false` to disable it.

## Limitations

Recognizes supported boolean-literal comparisons, opposite literal `if`
results, neutral logical operands, double negation, and two-arm boolean switches.
It does not suggest replacing `read() && false` with `false`, because that
would discard evaluation. Findings are suggestions, not automatic rewrites.

See the [expression boundaries](SYNTAX_RULES.md#expression-boundaries).
