# `react/jsx-key`

Require stable keys on JSX elements created in supported collection maps.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Keys let React preserve element identity when collection contents change. This check recognizes supported `Array.map` and list mapping forms; it does not infer all custom collection helpers.

## Examples

### Incorrect

```rescript
let rows = users->Array.map(user => <li> {React.string(user.name)} </li>)
```

### Correct

```rescript
let rows = users->Array.map(user => <li key={user.id}> {React.string(user.name)} </li>)
```

An element written directly in an array is also a collection item and needs a
key; the rule checks these static arrays as well as supported map calls.

### Incorrect: static JSX array

```rescript
let rows = [<li> {React.string("Ada")} </li>]
```

### Correct: static JSX array

```rescript
let rows = [<li key="ada"> {React.string("Ada")} </li>]
```

## Configuration

`false` disables this rule. JSX analysis requires the React DOM adapter.

```json
{
  "jsxRuntime": "react-dom",
  "rules": {"react/jsx-key": true}
}
```

Run with `npx rescript-lint --config rescript-lint.json src/Example.res`.

## Limitations

Custom mapping helpers and dynamically generated children may not be recognized. Selecting this rule without `jsxRuntime` is an analysis error, not a clean result.
