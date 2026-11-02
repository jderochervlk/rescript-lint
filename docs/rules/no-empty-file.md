# `no-empty-file`

Disallow implementation files without meaningful declarations or expressions.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Remove an unused implementation file, or add its intended implementation.
Use file selection or overrides when intentionally empty generated files
must remain in the project.

## Examples

### Incorrect

```rescript
// Empty.res contains only this comment.
```

### Correct

```rescript
let initialized = true
```

## Configuration

```json
{
  "rules": {
    "no-empty-file": true
  }
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

Set the rule to `false` to disable it.

## Limitations

Whitespace, comments, and standalone attributes do not make an implementation
meaningful. Interface files (`.resi`) are exempt; an intentionally empty
interface can hide implementation details.

See the [policy contract](SYNTAX_RULES.md#policy-boundaries).
