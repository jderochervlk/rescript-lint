# `no-duplicate-condition`

Report repeated stable conditions in the same conditional chain.

- Category: `correctness`
- Enabled by default: Yes
- Autofix: No

Repeated conditions often indicate a copied branch that was not updated.

## Examples

### Incorrect

```rescript
let label = status => if status == #ready {
  "Ready"
} else if status == #ready {
  "Blocked"
} else {
  "Waiting"
}
```

### Correct

```rescript
let label = status => if status == #ready {
  "Ready"
} else if status == #blocked {
  "Blocked"
} else {
  "Waiting"
}
```

## Configuration

```json
{
  "rules": {
    "no-duplicate-condition": true
  }
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

Set the rule to `false` to disable it.

## Limitations

Checks supported `if`/`else if` conditions and switch guards with identical
patterns. Calls, field reads, and other unstable expressions are not assumed
unchanged between evaluations; an intervening unstable test resets tracking.
This is a syntax comparison, not a reachability proof.
