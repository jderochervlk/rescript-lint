# `no-empty-loop`

Flags `while` and `for` loops whose body contains only unit.

- Category: `suspicious`
- Enabled by default: No
- Autofix: No

An empty loop typically makes no progress and may spin indefinitely. Comments do not make a body nonempty; effectful expressions or sequences are not flagged.

## Examples

### Incorrect

```rescript
let wait = ready => {while ready() {()}}
```

### Correct

```rescript
let wait = (ready, step) => {while ready() {step()}}
```

## Configuration

Set the rule to `true` to enable it; `false` disables it. There are no rule-specific options.

```json
{
  "rules": {
    "no-empty-loop": true
  }
}
```

Run `npx rescript-lint --config rescript-lint.json src/Main.res`.
