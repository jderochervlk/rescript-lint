# `no-useless-catch`

Report try/catch expressions whose handlers only rethrow the caught exception.

- Category: `correctness`
- Enabled by default: Yes
- Autofix: No

A handler that does no work and immediately rethrows adds no recovery behavior.
Remove the redundant handler or handle the specific failure intentionally.

## Examples

### Incorrect

```rescript
let run = read => try {
  read()
} catch {
| caught => throw(caught)
}
```

### Correct

```rescript
let run = read => read()
```

Removing a handler does not satisfy a separate
[`no-unhandled-throws`](no-unhandled-throws.md) obligation. If `read` has a known
throws contract, use a real applicable handler instead.

Recovering from a specific expected exception is another valid correction:

### Incorrect: recovering from an expected exception

```rescript
@throws(Not_found)
let read = () => 42

let run = () => try {
  Some(read())
} catch {
| caught => throw(caught)
}
```

### Correct: recovering from an expected exception

```rescript
@throws(Not_found)
let read = () => 42

let run = () => try {
  Some(read())
} catch {
| Not_found => None
}
```

## Configuration

```json
{
  "rules": {
    "no-useless-catch": true
  }
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

Set the rule to `false` to disable it.

## Limitations

Every handler must be unguarded and immediately rethrow the original caught
value or a supported alias. Additional work, reconstructed exceptions, or
unresolved/shadowed throw functions prevent this finding. Ordinary switch
handlers are outside this rule's try/catch check.
