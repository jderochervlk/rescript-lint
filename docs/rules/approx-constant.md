# `approx-constant`

Prefer named mathematical constants over close floating-point approximations.

- Category: `suspicious`
- Enabled by default: No
- Autofix: No

A named constant communicates intent and avoids copying a rounded approximation.

## Examples

### Incorrect

```rescript
let circumference = radius => 2.0 *. 3.141592653589793 *. radius
```

### Correct

```rescript
let circumference = radius => 2.0 *. Math.Constants.pi *. radius
```

## Configuration

```json
{
  "rules": {
    "approx-constant": true
  }
}
```

```sh
npx rescript-lint --config rescript-lint.json src/Example.res
```

Set the rule to `false` to disable it.

## Limitations

Matches positive or negative float literals within `0.000005` of supported
`Math.Constants` values: `e`, `ln2`, `ln10`, `log2e`, `log10e`, `pi`,
`sqrt1_2`, and `sqrt2`. Coarse approximations such as `3.14` are not reported.
The rule does not infer what a number represents or resolve a local module
shadowing `Math`; replacement must be reviewed manually.

See the [expression boundaries](SYNTAX_RULES.md#expression-boundaries).
