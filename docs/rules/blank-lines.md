# `blank-lines`

Require blank-line separators at supported declaration and statement boundaries.

- Category: `style`
- Enabled by default: Yes
- Autofix: Yes, with `--fix`

Separate multiline declarations from the next declaration. The rule also
requires separators after externals and pipe statements/bindings, before
annotated value bindings, and around switch statements/bindings.

## Examples

### Incorrect

```rescript
let increment = value => {
  let next = value + 1
  next
}
let result = increment(1)
```

### Correct

```rescript
let increment = value => {
  let next = value + 1
  next
}

let result = increment(1)
```

## Configuration

```json
{
  "rules": {
    "blank-lines": true
  }
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
npx rescript-lint --config rescript-lint.json --fix src/Example.res
```

Set the rule to `false` to disable its findings and separator edits. There are
no rule-specific spacing options.

## Autofix and limitations

`--fix` formats each file with the bundled ReScript formatter, then applies
validated separator edits. Formatting still runs when this rule is disabled
or there are no findings. Fix mode verifies candidates and writes only after
validation; ordinary linting does not change files.

Supports `.res`, `.resi`, nested blocks, and JSX siblings. It does not remove
extra blank lines or insert padding inside braces, between switch cases, or
within arbitrary expression positions. Comments remain attached to the
appropriate neighboring statement.
