# `no-unhandled-throws`

Require applicable exception handling for calls with known throws contracts.

- Category: `correctness`
- Enabled by default: Yes
- Autofix: No

Handle every exception declared by a resolved `@throws` contract. Repeating the
annotation on the caller is not handling. The legacy `@raises` spelling is also
recognized, but new code should use `@throws`.

## Examples

### Incorrect

```rescript
@throws(Not_found)
let read = () => 42

let result = read()
```

### Correct

```rescript
@throws(Not_found)
let read = () => 42

let result = try {
  Some(read())
} catch {
| Not_found => None
}
```

The annotation is a declaration contract, even if this particular implementation
does not actually throw. A switch with applicable `exception` arms is another
supported handling form.

## Configuration

```json
{
  "rules": {
    "no-unhandled-throws": true
  }
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

Set the rule to `false` to disable it. Source-local contracts require no adapter.
To include project declarations, configure `"root": "."`. Optional
`"throwsRuntime": "rescript-12.3.1"` adds the pinned runtime contract inventory;
`throwsDependencies` selects explicit dependency packages.

## Limitations

Handlers protect their execution region, not deferred callbacks or their own
handler bodies. Guarded or partial patterns do not establish exhaustive coverage.
Unknown or unsupported required contracts cause analysis errors, not a clean
result. Promise rejection and async handling have deliberately bounded support.
A handler that simply rethrows currently counts as handling, but may trigger
[`no-useless-catch`](no-useless-catch.md).

See [throws analysis](../analysis/THROWS.md) for supported annotations, project
and dependency metadata, runtime adapters, async behavior, and explicit failures.
