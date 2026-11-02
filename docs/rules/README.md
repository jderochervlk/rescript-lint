# Rule reference

The [rule list in the project README](../../README.md#rules) links to a page for
every registered rule. Each page documents default activation, category,
autofix support, incorrect and correct ReScript examples, configuration, and
relevant analysis boundaries.

“Incorrect” and “Correct” refer to the named rule, not every optional policy.
Short excerpts may use application helpers or values from their surrounding
module; examples requiring project files show their layout explicitly.

## Reference conventions

Rule pages live at `<rule-id>.md`, preserving namespaces as directories. For
example, `no-console` is documented in [no-console.md](no-console.md), and
`react/jsx-key` in [react/jsx-key.md](react/jsx-key.md). Rule configuration uses
booleans, not ESLint severity strings or arrays.

When adding or changing a rule, update its page and README entry in the same
change. Keep the ID, category, and default activation aligned with the rule's
metadata and catalog. Examples with nondefault limits must show those limits
in their configuration; adapter and project prerequisites must be explicit.
Only advertise autofix support when the rule actually supplies fixes.

Keep examples and relevant limitations on the individual rule page rather than
redirecting readers to an aggregate examples or boundaries document. Equivalent
examples should be consolidated; distinct scenarios can use named
`### Incorrect: <scenario>` and `### Correct: <scenario>` pairs after the
primary pair, with the same documented configuration.

## Detailed contracts

- [Original rules and shared API resolution](RULES.md)
- [Syntax rules](SYNTAX_RULES.md)
- [Semantic, JSX, React, test, and project rules](EXTENDED_RULES.md)
- [Additional policies](POLICY_EXPANSION.md)
- [Blank lines and fix safety](BLANK_LINES.md)
- [Unsafe API inventory](UNSAFE_APIS.md)
- [Throws analysis](../analysis/THROWS.md)
- [Configuration and inspection](../configuration/CONFIGURATION.md)

The compiler audit reads examples and configuration directly from the individual
rule pages, so there is no separate examples catalog to keep synchronized.

## Compiler audit

Build the linter, then prepare a temporary fixture project with ReScript
12.3.1, `@rescript/react` 0.15.0, and `rescript-vitest` 3.0.1:

```sh
make build
FIXTURE_PROJECT=$(mktemp -d)
npm install --prefix "$FIXTURE_PROJECT" rescript@12.3.1 @rescript/react@0.15.0 rescript-vitest@3.0.1
node scripts/examples/audit-rule-examples.mjs _build/default/bin/main.exe "$FIXTURE_PROJECT"
```

Use a temporary directory, not an application checkout: the audit generates
fixture projects and a JSON report there. It compiles primary and named example
pairs, uses each page's configuration, and checks each half with only its target
rule enabled. Multi-file examples retain their documented file layout, and
unused-export cases use real fresh Reanalyze output.

Application-context excerpts use the typed fixture in
`scripts/examples/rule-example-prelude.res`; empty-file, file-length, and
license-header examples retain their original source semantics. Missing pages,
unpaired examples, invalid configuration, compiler failures, and unavailable
analysis evidence fail the audit rather than being counted as passing examples.
