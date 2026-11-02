# `no-identical-branches`

Report adjacent branches with structurally identical bodies.

- Category: `suspicious`
- Enabled by default: Yes
- Autofix: No

Identical branches can hide a copy-and-paste mistake or unnecessary branching.
If the condition has effects, preserve them when simplifying manually.

## Examples

### Incorrect

```rescript
let label = ready => if ready {"Ready"} else {"Ready"}
```

### Correct

```rescript
let label = ready => if ready {"Ready"} else {"Waiting"}
```

## Configuration

```json
{
  "rules": {
    "no-identical-branches": true
  }
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

Set the rule to `false` to disable it.

## Limitations

Compares adjacent `if`/`else if`/`else` bodies and supported switch result arms.
Switch patterns must be identical or the result bodies must not depend on
either arm's pattern bindings. Comments and locations do not distinguish
otherwise identical bodies; attributes do.

See the [control-flow contract](RULES.md#control-flow-rules).
