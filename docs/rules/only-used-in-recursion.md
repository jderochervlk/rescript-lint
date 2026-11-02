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

Checks direct full-arity self-calls with matching argument positions, labels,
and lexical identities. A parameter used elsewhere or transformed before being
forwarded is not merely passed through. Higher-order and indirect recursion are
not inferred.
