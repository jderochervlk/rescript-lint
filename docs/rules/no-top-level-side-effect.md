# `no-top-level-side-effect`

Restricts recognized effectful module initialization outside configured entry modules.

- Category: `restriction`
- Enabled by default: No
- Autofix: No

Move startup work into an explicit function called by the application entry point, keeping reusable modules from performing unexpected work when loaded.

## Examples

### Incorrect

```rescript
// In src/Feature.res, not a configured entry module:
Console.log("module loaded")
```

### Correct

```rescript
let initialize = () => Console.log("application started")
```

## Configuration

```json
{
  "root": ".",
  "entryModules": ["Main"],
  "rules": {
    "no-top-level-side-effect": true
  }
}
```

`entryModules` contains module names relative to the configured project source set. Set the rule to `false` to disable it. Run `rescript-lint --config rescript-lint.json` to analyze the project; project discovery uses the configured root and `rescript.json`.

## Limitations

Only recognized initialization effects are checked. Configured entry modules are exempt, and this analysis does not establish that arbitrary function bodies are pure.

See [project rules and analysis boundaries](EXTENDED_RULES.md#project-rules) and [audited examples](RULE_EXAMPLES.md#no-top-level-side-effect).
