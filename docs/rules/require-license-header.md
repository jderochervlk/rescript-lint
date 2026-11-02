# `require-license-header`

Requires an applicable source file to begin with a license comment containing the configured SPDX license identifier.

- Category: `restriction`
- Enabled by default: No
- Autofix: No

The expected line is exact: `SPDX-License-Identifier: LICENSE`. The default license is MIT; configure `license` to match the project.

## Examples

### Incorrect

```rescript
let answer = 42
```

### Correct

```rescript
// Copyright 2026 Example Authors
// SPDX-License-Identifier: MIT
let answer = 42
```

## Configuration

```json
{
  "license": "MIT",
  "rules": {
    "require-license-header": true
  }
}
```

Replace `MIT` with the project's license identifier. Set the rule to `false` to disable it. Run `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

The identifier must be in an ordinary leading comment; text after code or a string literal does not count. The linter checks the configured identifier, not legal compliance.
