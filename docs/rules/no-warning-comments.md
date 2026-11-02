# `no-warning-comments`

Report configured warning terms in source comments.

- Category: `pedantic`
- Enabled by default: No
- Autofix: No

Use this rule when unresolved TODO-style notes should prevent a clean lint run.
Resolve the underlying work rather than merely removing its warning comment.

## Examples

### Incorrect

```rescript
// TODO: remove this fallback
let timeout = 1000
```

### Correct

```rescript
// The fallback matches the legacy service timeout.
let timeout = 1000
```

## Configuration

```json
{
  "rules": {
    "no-warning-comments": true
  },
  "warningComments": {
    "terms": ["TODO", "FIXME", "HACK"],
    "allowedContexts": []
  }
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

The example shows the defaults. `terms` must be a nonempty list of ASCII
identifiers, unique ignoring ASCII case. `allowedContexts` can exempt `"line"`,
`"block"`, or `"documentation"` comments. Set the rule to `false` to disable it.

## Limitations

Terms match whole words ignoring ASCII case: `TODO` matches, but `TODO_LIST`
does not. Checks real parsed comments and documentation comments, not string
literals or arbitrary annotation strings. One finding lists the matched terms
for each comment.

See the [syntax reference](SYNTAX_RULES.md#policy-boundaries).
