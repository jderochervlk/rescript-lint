# `no-floating-promise`

Reports recognized promise values that are discarded rather than handled or returned to a caller.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Await the operation and handle failures, return the promise to a caller that owns its lifecycle, or explicitly choose a safe task-management boundary.

## Examples

### Incorrect

```rescript
let saveUser = async user => user

let handleSave = user => {
  saveUser(user)->ignore
}
```

### Correct

```rescript
let saveUser = async user => user

let handleSave = user => saveUser(user)
```

The caller now receives the promise and owns awaiting or otherwise handling it.

An async caller can instead await the operation itself:

### Incorrect: awaiting the operation

```rescript
let saveUser = async user => user

let handleSave = user => {
  saveUser(user)->ignore
}
```

### Correct: awaiting the operation

```rescript
let saveUser = async user => user

let handleSave = async user => await saveUser(user)
```

## Configuration

```json
{
  "rules": {
    "no-floating-promise": true
  }
}
```

Set the value to `false` to disable this rule.
Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Checks wildcard bindings and resolved standard or promise-specific `ignore`
calls when the discarded value is known to be a promise. Missing required type
information fails analysis. Storing a promise in a named binding is not
reported and does not prove that it will eventually be handled.
