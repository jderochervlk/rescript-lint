# `only-used-in-recursion`

Finds parameters in supported recursive functions that are only forwarded unchanged through recursive calls.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Remove a parameter that contributes no value to the recursive computation, or use it meaningfully if it is required by the algorithm.

## Examples

### Incorrect

```rescript
let rec contains = (items, config, wanted) => switch items {
| list{} => false
| list{head, ...tail} => head == wanted || contains(tail, config, wanted)
}
```

### Correct

```rescript
let rec contains = (items, wanted) => switch items {
| list{} => false
| list{head, ...tail} => head == wanted || contains(tail, wanted)
}
```

## Configuration

```json
{
  "rules": {
    "only-used-in-recursion": true
  }
}
```

Set the value to `false` to disable this rule. Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

The analysis recognizes supported recursive-call shapes and does not infer arbitrary higher-order or indirect recursion.

See [semantic rule boundaries](EXTENDED_RULES.md#semantic-rules) and [audited examples](RULE_EXAMPLES.md#only-used-in-recursion).
