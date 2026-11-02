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

Functions returning a recognized promise are allowed without an `await`; do not
add redundant awaits merely to satisfy the rule. An await inside a nested
function or a syntactically unreachable branch does not satisfy the outer
async function.

An intentional signature adapter can be marked with `@lint.promiseAdapter`.
Unknown necessary return-type facts produce analysis errors rather than being
assumed to be promises.
