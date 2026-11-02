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

Detection is based on known promise values and supported handling forms; an unreported asynchronous operation is not proof that its failure is managed.

See [semantic rule boundaries](EXTENDED_RULES.md#semantic-rules) and [audited examples](RULE_EXAMPLES.md#no-floating-promise).
