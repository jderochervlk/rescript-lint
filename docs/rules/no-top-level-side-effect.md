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

Recognizes supported initialization effects including console calls, known
dynamic-code and partial runtime calls, executable raw code, assignment, await,
and assert. Deferred function bodies are not module initialization, and
configured entry modules are exempt.

Arbitrary user-function calls are not transitively effect-analyzed. No finding
does not prove that an initializer or a called function is pure.
