# `no-deprecated-api`

Flags references resolved to declarations marked `@deprecated`.

- Category: `pedantic`
- Enabled by default: No
- Autofix: No

Use the replacement named in the deprecation message where it is suitable.

## Examples

### Incorrect

```rescript
module Api = {
  let fetchUser = id => id
  @deprecated("Use fetchUser instead")
  let loadUser = id => fetchUser(id)
}
let fetch = id => Api.loadUser(id)
```

### Correct

```rescript
module Api = {
  let fetchUser = id => id
  @deprecated("Use fetchUser instead")
  let loadUser = id => fetchUser(id)
}
let fetch = id => Api.fetchUser(id)
```

## Configuration

```json
{
  "rules": {
    "no-deprecated-api": true
  }
}
```

Set the value to `false` to disable this rule. Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

The rule relies on resolved declaration metadata, including supported public interface metadata and local aliases. Unresolved references are not assumed deprecated.

See [project rule boundaries](EXTENDED_RULES.md#project-rules) and [audited examples](RULE_EXAMPLES.md#no-deprecated-api).
