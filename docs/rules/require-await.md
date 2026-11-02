# `require-await`

Flags async functions that contain no effective `await` and do not return a promise.

- Category: `pedantic`
- Enabled by default: No
- Autofix: No

Remove unnecessary async behavior or await the intended asynchronous operation.

## Examples

### Incorrect

```rescript
let loadCount = async () => 42
```

### Correct

```rescript
let loadCount = async () => await fetchCount()
```

## Configuration

```json
{
  "rules": {
    "require-await": true
  }
}
```

Set the value to `false` to disable this rule. Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Functions returning a recognized promise are allowed even without an `await`; this is not a requirement to add redundant awaits.

See [semantic rule boundaries](EXTENDED_RULES.md#semantic-rules) and [audited examples](RULE_EXAMPLES.md#require-await).
