# `no-console`

Disallow references to standard console and logging APIs.

- Category: `restriction`
- Enabled by default: Yes
- Autofix: No

Keep application code from accidentally writing debug output or sensitive data.
Return useful values to the caller, or use an intentional application-level
logging boundary instead.

## Examples

### Incorrect

```rescript
let greeting = name => {
  Console.log(name)
  "Hello, " ++ name
}
```

### Correct

```rescript
let greeting = name => "Hello, " ++ name
```

## Configuration

```json
{
  "rules": {
    "no-console": true
  }
}
```

Save as `rescript-lint.json`, then run:

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

Set the rule to `false` to disable it.

## Limitations

Checks the pinned ReScript 12.3.1 console inventory, including modern `Console`
and legacy `Js` exports. Known module aliases, opens, includes, and lexical
shadowing participate in resolution. Capturing a logging function as a value
is reported at the capture; subsequent references to that value are not reported
again. Arbitrary custom logging bindings and raw JavaScript are outside this
inventory.

Removing a call can discard side effects in its arguments, so the rule does not
automatically delete logging statements.
