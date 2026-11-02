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

## Detailed contracts

- [Original rules and shared API resolution](RULES.md)
- [Syntax rules](SYNTAX_RULES.md)
- [Semantic, JSX, React, test, and project rules](EXTENDED_RULES.md)
- [Additional policies](POLICY_EXPANSION.md)
- [Blank lines and fix safety](BLANK_LINES.md)
- [Unsafe API inventory](UNSAFE_APIS.md)
- [Throws analysis](../analysis/THROWS.md)
- [Configuration and inspection](../configuration/CONFIGURATION.md)

The older [aggregate examples](RULE_EXAMPLES.md) and their compiler audit remain
available as historical validation material. The individual rule pages are the
user-facing entry point.
