# ReScript Linter

A native linter for [ReScript](https://rescript-lang.org/). It checks `.res`
and `.resi` source directly, without requiring an OCaml toolchain or a ReScript
build for syntax rules.

124 rules for correctness, readability, performance, React, accessibility, tests,
and project policies. Twelve rules are enabled by default; the rest are opt-in.
Each [rule](#rules) has examples, configuration, and autofix information.

This project is in alpha. The rule list describes the current repository;
`npx rescript-lint --list-rules` shows what your installed version supports.

- [Install](#install)
- [Usage](#usage)
- [Configuration](#configuration)
- [Editor integrations](#editor-integrations)
- [Rules](#rules)

## Install

Install the linter as a development dependency. It requires Node.js 24 or
newer:

```sh
npm install --save-dev @jvlk/rescript-lint@alpha
```

The package includes a prebuilt native executable, so consumers do not need
OCaml, Opam, Dune, or a compiler checkout. Native targets are Linux glibc and
macOS on x64/ARM64, and Windows on x64. Alpine/musl, Windows ARM64, and 32-bit
systems are not supported. Do not install a platform-specific package directly
or use `--omit=optional`.

For editor diagnostics, also install the [VS Code or Zed integration](#editor-integrations).

## Usage

Lint explicit files:

```sh
npx rescript-lint src/Main.res src/Api.resi
```

Or lint a project. With no file arguments, `--project` discovers source files
from that directory's `rescript.json`:

```sh
npx rescript-lint --project .
```

Discovery selects only that project's `sources`, after configured `exclude`
filters. It does not lint dependencies automatically. A zero-file selection
prints a warning but retains exit code 0 for legitimate empty projects.
JSON results expose `checkedFileCount` and `warnings`, so CI can reject empty
runs explicitly.

For an aggregating workspace root with `"sources": []`, select each first-party
child project in a separate invocation:

```sh
npx rescript-lint --project example-app
npx rescript-lint --project packages/ui
```

Run both commands in your task runner/CI and preserve each exit status.
`--project` selects one project; repeating it does not aggregate projects.
See [project selection](docs/features/empty-project-discovery.md) for the
reporting contract and boundaries.

Common day-to-day commands:

```sh
npx rescript-lint --watch --project .
npx rescript-lint --fix src/Main.res
npx rescript-lint --list-rules
npx rescript-lint --format json --project .
```

`--fix` formats files with the bundled ReScript formatter, then applies available
rule fixes and saves the combined result. Formatting also runs when there are no
lint findings; it does not mean every rule has an autofix. Currently,
[`blank-lines`](docs/rules/blank-lines.md) is the only rule with automatic fixes.

`--watch` reruns after relevant source or configuration changes.
`--format json` emits one [versioned JSON result](docs/diagnostics/JSON_DIAGNOSTICS.md)
per run for CI and other integrations.

Add a script for routine use:

```json
{
  "scripts": {
    "lint": "rescript-lint --project ."
  }
}
```

Then run `npm run lint`. A clean run exits `0`, lint findings exit `1`, and
usage, input, parsing, analysis, fix, or write failures exit `2`.

Findings include a `Docs: URL` link to the rule's examples and configuration.
JSON diagnostics expose the same target as `documentationUrl`; editor clients
can display it as a clickable rule code through standard LSP metadata.

## Configuration

Create `rescript-lint.json` in your project:

```json
{
  "$schema": "./node_modules/@jvlk/rescript-lint/config.schema.json",
  "root": ".",
  "jsxRuntime": "react-dom",
  "rules": {
    "no-console": false,
    "jsx-a11y/alt-text": true,
    "react/jsx-key": true,
    "no-warning-comments": true
  }
}
```

Pass it explicitly when running the CLI; configuration files are not
automatically discovered:

```sh
npx rescript-lint --config rescript-lint.json
```

Rule settings are booleans: `true` enables a rule and `false` disables it.
Unspecified rules retain their defaults. All findings are errors; there is no
warning severity. For one-off selection, use:

```sh
npx rescript-lint --enable-rule no-empty-function --disable-rule no-console src/Main.res
```

Base settings follow argument order. [Per-file overrides](docs/configuration/CONFIGURATION.md)
apply afterward, in declaration order.

Optional JSX and React rules require `"jsxRuntime": "react-dom"`; the default
`react/rules-of-hooks` rule does not. Test rules require
`"testFramework": "rescript-vitest-3"`. Some semantic and project rules need
additional context. Each rule page explains its prerequisites and options.

Paths in the file are relative to that file, except `exclude`, whose entries
are relative to the configured `root`. For a config in `config/` with
`"root": ".."`, use `"exclude": ["src/generated"]`, not `"../src/generated"`.

Use `--inspect-config src/Main.res --config rescript-lint.json --format json`
to inspect effective per-file rules, origins, options, and adapter requirements
without reading or linting the source. See the
[configuration guide](docs/configuration/CONFIGURATION.md) and
[extended reference](docs/rules/EXTENDED_RULES.md) for options, overrides, and
[suppression comments](docs/rules/EXTENDED_RULES.md#suppressions).

## Editor integrations

The linter runs alongside ReScript's compiler-backed language server, not in
place of it. Both integrations below are development builds and are **not yet
published in their editors' extension registries**.

### VS Code

1. Install Node.js 24+, [pnpm](https://pnpm.io/installation), and VS Code 1.126+.
2. Install `@jvlk/rescript-lint@alpha` in your ReScript project as shown above.
3. Build the [ReScript Lint extension](https://github.com/jderochervlk/rescript-lint-vscode):

   ```sh
   git clone https://github.com/jderochervlk/rescript-lint-vscode.git
   cd rescript-lint-vscode
   pnpm install
   pnpm package
   ```

4. In VS Code, run **Extensions: Install from VSIX...** and select the generated
   `rescript-lint-vscode-*.vsix` file. Install the
   [official ReScript extension](https://marketplace.visualstudio.com/items?itemName=chenglou92.rescript-vscode)
   too if it was not installed automatically.
5. Open a trusted ReScript workspace and a `.res` or `.resi` file.

The extension uses the workspace's
`node_modules/@jvlk/rescript-lint/bin/rescript-lint.mjs`, falling back to
`rescript-lint` on `PATH`. To use a native executable explicitly:

```json
{
  "rescriptLint.serverPath": "/absolute/path/to/rescript-lint"
}
```

Use **ReScript Lint: Restart Language Server** after changing settings and
**ReScript Lint: Show Output** for startup problems. The extension currently
starts the server with default rules; it does not automatically load
`rescript-lint.json` or expose a server-arguments setting. See its
[installation and settings guide](https://github.com/jderochervlk/rescript-lint-vscode#local-linter)
for Node.js paths, remote workspaces, and development builds.

### Zed

1. Install [Zed](https://zed.dev), Node.js 24+, and
   [Rust via rustup](https://rustup.rs/).
2. Install `@jvlk/rescript-lint@alpha` in your ReScript project as shown above.
3. Clone the [ReScript Lint Zed extension](https://github.com/jderochervlk/rescript-lint-zed):

   ```sh
   git clone https://github.com/jderochervlk/rescript-lint-zed.git
   ```

4. In Zed's command palette, run **zed: install dev extension** (or choose
   **Install Dev Extension** on the Extensions page) and select that directory.
   Zed builds the extension automatically.
5. Configure the linter binary in Zed settings to use your installed package:

   ```json
   {
     "lsp": {
       "rescript-lint": {
         "binary": {
           "path": "/absolute/path/to/node",
           "arguments": [
             "/absolute/path/to/project/node_modules/@jvlk/rescript-lint/bin/rescript-lint.mjs",
             "lsp",
             "--stdio",
             "--config",
             "/absolute/path/to/project/rescript-lint.json"
           ]
         }
       }
     }
   }
   ```

   Use real absolute paths, and create the configuration file first. Omit
   `--config` and its following path to use the default rules.

This development extension uses the same `rescript` ID as Zed's official
ReScript extension and overrides it. Its automatic npm fallback is pinned to
the older Linux-only `0.1.0-alpha.1` package and its `.cjs` launcher. The explicit
override above uses the current `.mjs` launcher instead; changing only the
extension's version setting is not sufficient. See the extension's
[installation guide](https://github.com/jderochervlk/rescript-lint-zed#installation-development-extension)
for updates and limitations.

### Other LSP clients

Start the language server over stdio:

```sh
npx rescript-lint lsp --stdio --config rescript-lint.json
```

It publishes diagnostics for open `.res` and `.resi` buffers, including unsaved
edits. See the [language-server guide](docs/editor/LSP.md) for the protocol and
supported capabilities.

## Rules

✅ Enabled by default. 🔧 Automatically fixable with `--fix`. A dash means
opt-in or no rule-specific autofix, respectively. Category does not determine
activation.

Every rule name links to its examples and configuration. Semantic analysis is
bounded: no finding is not proof of safety, and missing required information
can produce an analysis failure instead of a clean result. Consult each rule's
limitations before using it as an enforcement gate.

<!-- Rule tables follow the current rule catalog. -->

### Correctness

| Rule | Description | Default | Autofix |
| --- | --- | :---: | :---: |
| [jsx-a11y/alt-text](docs/rules/jsx-a11y/alt-text.md) | Require text alternatives for images and image-like content. | — | — |
| [jsx-a11y/anchor-has-content](docs/rules/jsx-a11y/anchor-has-content.md) | Require accessible link content. | — | — |
| [jsx-a11y/anchor-is-valid](docs/rules/jsx-a11y/anchor-is-valid.md) | Use anchors for navigation and buttons for actions. | — | — |
| [jsx-a11y/aria-activedescendant-has-tabindex](docs/rules/jsx-a11y/aria-activedescendant-has-tabindex.md) | Make active-descendant owners keyboard focusable. | — | — |
| [jsx-a11y/aria-role](docs/rules/jsx-a11y/aria-role.md) | Use recognized concrete ARIA roles. | — | — |
| [jsx-a11y/aria-unsupported-elements](docs/rules/jsx-a11y/aria-unsupported-elements.md) | Avoid ARIA on unsupported metadata elements. | — | — |
| [jsx-a11y/autocomplete-valid](docs/rules/jsx-a11y/autocomplete-valid.md) | Use valid autocomplete tokens. | — | — |
| [jsx-a11y/click-events-have-key-events](docs/rules/jsx-a11y/click-events-have-key-events.md) | Pair non-native click behavior with keyboard activation. | — | — |
| [jsx-a11y/control-has-associated-label](docs/rules/jsx-a11y/control-has-associated-label.md) | Give form controls accessible names. | — | — |
| [jsx-a11y/heading-has-content](docs/rules/jsx-a11y/heading-has-content.md) | Require accessible heading content. | — | — |
| [jsx-a11y/html-has-lang](docs/rules/jsx-a11y/html-has-lang.md) | Declare the document language. | — | — |
| [jsx-a11y/iframe-has-title](docs/rules/jsx-a11y/iframe-has-title.md) | Give frames descriptive titles. | — | — |
| [jsx-a11y/img-redundant-alt](docs/rules/jsx-a11y/img-redundant-alt.md) | Avoid redundant image wording in alternative text. | — | — |
| [jsx-a11y/interactive-supports-focus](docs/rules/jsx-a11y/interactive-supports-focus.md) | Make interactive-role elements focusable. | — | — |
| [jsx-a11y/label-has-associated-control](docs/rules/jsx-a11y/label-has-associated-control.md) | Associate labels with controls. | — | — |
| [jsx-a11y/lang](docs/rules/jsx-a11y/lang.md) | Use valid language tags. | — | — |
| [jsx-a11y/media-has-caption](docs/rules/jsx-a11y/media-has-caption.md) | Provide audio and video captions. | — | — |
| [jsx-a11y/mouse-events-have-key-events](docs/rules/jsx-a11y/mouse-events-have-key-events.md) | Pair mouse behavior with focus and blur behavior. | — | — |
| [jsx-a11y/no-access-key](docs/rules/jsx-a11y/no-access-key.md) | Avoid conflicting access-key shortcuts. | — | — |
| [jsx-a11y/no-aria-hidden-on-focusable](docs/rules/jsx-a11y/no-aria-hidden-on-focusable.md) | Keep focusable elements in the accessibility tree. | — | — |
| [jsx-a11y/no-autofocus](docs/rules/jsx-a11y/no-autofocus.md) | Avoid automatic focus changes. | — | — |
| [jsx-a11y/no-distracting-elements](docs/rules/jsx-a11y/no-distracting-elements.md) | Avoid blinking and scrolling elements. | — | — |
| [jsx-a11y/no-interactive-element-to-noninteractive-role](docs/rules/jsx-a11y/no-interactive-element-to-noninteractive-role.md) | Preserve native interactive semantics. | — | — |
| [jsx-a11y/no-noninteractive-element-interactions](docs/rules/jsx-a11y/no-noninteractive-element-interactions.md) | Use interactive elements for interaction handlers. | — | — |
| [jsx-a11y/no-noninteractive-element-to-interactive-role](docs/rules/jsx-a11y/no-noninteractive-element-to-interactive-role.md) | Avoid interactive roles on noninteractive semantic elements. | — | — |
| [jsx-a11y/no-noninteractive-tabindex](docs/rules/jsx-a11y/no-noninteractive-tabindex.md) | Keep noninteractive content out of the tab order. | — | — |
| [jsx-a11y/no-redundant-roles](docs/rules/jsx-a11y/no-redundant-roles.md) | Omit redundant explicit roles. | — | — |
| [jsx-a11y/no-static-element-interactions](docs/rules/jsx-a11y/no-static-element-interactions.md) | Give interactive behavior suitable semantics. | — | — |
| [jsx-a11y/prefer-tag-over-role](docs/rules/jsx-a11y/prefer-tag-over-role.md) | Prefer native HTML elements over equivalent roles. | — | — |
| [jsx-a11y/role-has-required-aria-props](docs/rules/jsx-a11y/role-has-required-aria-props.md) | Include required ARIA properties. | — | — |
| [jsx-a11y/role-supports-aria-props](docs/rules/jsx-a11y/role-supports-aria-props.md) | Use properties supported by the element's role. | — | — |
| [jsx-a11y/scope](docs/rules/jsx-a11y/scope.md) | Use `scope` only on table header cells. | — | — |
| [jsx-a11y/tabindex-no-positive](docs/rules/jsx-a11y/tabindex-no-positive.md) | Avoid positive tab indices. | — | — |
| [no-constant-binary-expression](docs/rules/no-constant-binary-expression.md) | Report binary expressions with fixed results. | ✅ | — |
| [no-constant-condition](docs/rules/no-constant-condition.md) | Report statically fixed conditions. | ✅ | — |
| [no-debugger](docs/rules/no-debugger.md) | Disallow `%debugger` expressions. | ✅ | — |
| [no-duplicate-condition](docs/rules/no-duplicate-condition.md) | Report repeated stable conditions. | ✅ | — |
| [no-empty-file](docs/rules/no-empty-file.md) | Disallow empty implementation files. | — | — |
| [no-erasing-operation](docs/rules/no-erasing-operation.md) | Report integer multiplication by zero. | — | — |
| [no-floating-promise](docs/rules/no-floating-promise.md) | Handle or return known promises. | — | — |
| [no-identity-operation](docs/rules/no-identity-operation.md) | Report integer operations that leave a value unchanged. | — | — |
| [no-ignored-result](docs/rules/no-ignored-result.md) | Handle or return known result values. | — | — |
| [no-modulo-one](docs/rules/no-modulo-one.md) | Report remainder operations by one or negative one. | — | — |
| [no-object-magic](docs/rules/no-object-magic.md) | Disallow unchecked casts through `Obj.magic`. | ✅ | — |
| [no-partial-function](docs/rules/no-partial-function.md) | Prefer total alternatives to known partial runtime APIs. | — | — |
| [no-unhandled-throws](docs/rules/no-unhandled-throws.md) | Handle declared exceptions at applicable call sites. | ✅ | — |
| [no-unsafe](docs/rules/no-unsafe.md) | Disallow known unsafe standard-library APIs. | ✅ | — |
| [no-unused-export](docs/rules/no-unused-export.md) | Report unused public declarations using Reanalyze evidence. | — | — |
| [no-useless-catch](docs/rules/no-useless-catch.md) | Report catches that only rethrow. | ✅ | — |
| [only-used-in-recursion](docs/rules/only-used-in-recursion.md) | Report parameters only forwarded through recursive calls. | — | — |
| [react/exhaustive-deps](docs/rules/react/exhaustive-deps.md) | Include captured reactive values in hook dependencies. | — | — |
| [react/jsx-key](docs/rules/react/jsx-key.md) | Require keys on supported collection-generated JSX. | — | — |
| [react/no-children-prop](docs/rules/react/no-children-prop.md) | Pass children through JSX child syntax. | — | — |
| [react/no-danger-with-children](docs/rules/react/no-danger-with-children.md) | Do not combine raw HTML with children. | — | — |
| [react/void-dom-elements-no-children](docs/rules/react/void-dom-elements-no-children.md) | Keep children and raw HTML off void elements. | — | — |
| [test/expect-expect](docs/rules/test/expect-expect.md) | Require a recognized assertion in each test. | — | — |
| [test/no-conditional-expect](docs/rules/test/no-conditional-expect.md) | Avoid conditionally skipped assertions. | — | — |
| [test/no-conditional-test](docs/rules/test/no-conditional-test.md) | Register tests unconditionally. | — | — |
| [test/no-disabled-tests](docs/rules/test/no-disabled-tests.md) | Disallow skipped and todo tests. | — | — |
| [test/no-focused-tests](docs/rules/test/no-focused-tests.md) | Disallow focused tests and suites. | — | — |
| [test/valid-title](docs/rules/test/valid-title.md) | Require nonempty test and suite titles. | — | — |

### Suspicious

| Rule | Description | Default | Autofix |
| --- | --- | :---: | :---: |
| [approx-constant](docs/rules/approx-constant.md) | Prefer named mathematical constants. | — | — |
| [no-empty-loop](docs/rules/no-empty-loop.md) | Report loops with literal unit bodies. | — | — |
| [no-identical-branches](docs/rules/no-identical-branches.md) | Report adjacent identical branch bodies. | ✅ | — |
| [no-shared-array-initializer](docs/rules/no-shared-array-initializer.md) | Avoid sharing mutable initializers between array slots. | — | — |
| [no-unintended-shallow-equality](docs/rules/no-unintended-shallow-equality.md) | Avoid unintended identity comparison of compound values. | — | — |
| [no-useless-concat](docs/rules/no-useless-concat.md) | Avoid concatenating literals or empty strings. | — | — |
| [react/iframe-missing-sandbox](docs/rules/react/iframe-missing-sandbox.md) | Declare an iframe sandbox. | — | — |
| [react/no-unstable-nested-components](docs/rules/react/no-unstable-nested-components.md) | Declare components outside render functions. | — | — |

### Pedantic

| Rule | Description | Default | Autofix |
| --- | --- | :---: | :---: |
| [max-lines](docs/rules/max-lines.md) | Limit physical lines per file. | — | — |
| [max-lines-per-function](docs/rules/max-lines-per-function.md) | Limit physical lines per function. | — | — |
| [max-nesting](docs/rules/max-nesting.md) | Limit control-flow nesting. | — | — |
| [max-switch-cases](docs/rules/max-switch-cases.md) | Limit switch arms. | — | — |
| [no-deprecated-api](docs/rules/no-deprecated-api.md) | Avoid resolved deprecated declarations. | — | — |
| [no-float-equality](docs/rules/no-float-equality.md) | Avoid exact equality on computed floats. | — | — |
| [no-negated-condition](docs/rules/no-negated-condition.md) | Prefer positive conditions in two-branch `if` expressions. | — | — |
| [no-self-compare](docs/rules/no-self-compare.md) | Report stable self-comparisons. | — | — |
| [no-warning-comments](docs/rules/no-warning-comments.md) | Report configured warning terms in comments. | — | — |
| [react/jsx-no-target-blank](docs/rules/react/jsx-no-target-blank.md) | Protect links opened in new browsing contexts. | — | — |
| [react/rules-of-hooks](docs/rules/react/rules-of-hooks.md) | Enforce supported hook placement conventions. | ✅ | — |
| [require-await](docs/rules/require-await.md) | Avoid async functions without effective await or returned promises. | — | — |

### Performance

| Rule | Description | Default | Autofix |
| --- | --- | :---: | :---: |
| [fuse-collection-pipeline](docs/rules/fuse-collection-pipeline.md) | Combine supported pure collection transformations. | — | — |
| [no-accumulating-concat](docs/rules/no-accumulating-concat.md) | Avoid repeatedly concatenating a growing string in reduce. | — | — |
| [no-await-in-loop](docs/rules/no-await-in-loop.md) | Avoid sequential awaits in known independent loops. | — | — |
| [no-expensive-deep-equality](docs/rules/no-expensive-deep-equality.md) | Limit known structural-comparison risk. | — | — |
| [prefer-empty-check](docs/rules/prefer-empty-check.md) | Prefer direct empty-collection checks. | — | — |
| [prefer-pattern-check](docs/rules/prefer-pattern-check.md) | Prefer supported constructor-pattern checks. | — | — |
| [react/jsx-no-constructed-context-values](docs/rules/react/jsx-no-constructed-context-values.md) | Avoid fresh provider values on every render. | — | — |
| [react/no-array-index-key](docs/rules/react/no-array-index-key.md) | Avoid collection indices as React keys. | — | — |
| [react/no-new-prop-value](docs/rules/react/no-new-prop-value.md) | Avoid fresh non-special prop values during render. | — | — |

### Style

| Rule | Description | Default | Autofix |
| --- | --- | :---: | :---: |
| [blank-lines](docs/rules/blank-lines.md) | Require supported blank-line separators. | ✅ | 🔧 |
| [eta-reduction](docs/rules/eta-reduction.md) | Prefer direct function references over forwarding wrappers. | — | — |
| [max-params](docs/rules/max-params.md) | Limit function parameters. | — | — |
| [no-nested-ternary](docs/rules/no-nested-ternary.md) | Avoid nested ternary expressions. | — | — |
| [no-optional-some](docs/rules/no-optional-some.md) | Avoid explicit `Some` in direct optional arguments. | — | — |
| [no-redundant-mutual-recursion](docs/rules/no-redundant-mutual-recursion.md) | Avoid recursive groups without the corresponding cycle. | — | — |
| [no-single-case-switch](docs/rules/no-single-case-switch.md) | Avoid switches with one unguarded, irrefutable arm. | — | — |
| [no-unnecessary-template](docs/rules/no-unnecessary-template.md) | Prefer strings over untagged templates without interpolation. | — | — |
| [prefer-if](docs/rules/prefer-if.md) | Prefer `if` to supported two-case boolean switches. | — | — |
| [prefer-standard-combinator](docs/rules/prefer-standard-combinator.md) | Prefer standard combinators to supported manual recursion. | — | — |
| [preferred-type-syntax](docs/rules/preferred-type-syntax.md) | Prefer `dict<a>` to the standard `Dict.t<a>` alias. | — | — |
| [simplify-boolean-expression](docs/rules/simplify-boolean-expression.md) | Simplify redundant boolean syntax. | — | — |
| [test/max-nested-describe](docs/rules/test/max-nested-describe.md) | Limit nested test suites. | — | — |
| [test/no-duplicate-hooks](docs/rules/test/no-duplicate-hooks.md) | Avoid repeated same-scope lifecycle hooks. | — | — |
| [test/no-identical-title](docs/rules/test/no-identical-title.md) | Require unique sibling titles of the same registration kind. | — | — |
| [test/prefer-hooks-in-order](docs/rules/test/prefer-hooks-in-order.md) | Order hooks as `beforeAll`, `beforeEach`, `afterEach`, `afterAll`. | — | — |
| [test/prefer-hooks-on-top](docs/rules/test/prefer-hooks-on-top.md) | Declare hooks before tests. | — | — |
| [test/require-top-level-describe](docs/rules/test/require-top-level-describe.md) | Group top-level tests in suites. | — | — |

### Restriction

| Rule | Description | Default | Autofix |
| --- | --- | :---: | :---: |
| [forbidden-source-root-reference](docs/rules/forbidden-source-root-reference.md) | Restrict references by declaration source root. | — | — |
| [jsx-a11y/anchor-ambiguous-text](docs/rules/jsx-a11y/anchor-ambiguous-text.md) | Avoid vague link labels. | — | — |
| [no-catch-all-exception](docs/rules/no-catch-all-exception.md) | Avoid swallowing every exception. | — | — |
| [no-console](docs/rules/no-console.md) | Disallow standard console and logging APIs. | ✅ | — |
| [no-dynamic-code](docs/rules/no-dynamic-code.md) | Restrict known dynamic-code APIs and raw JavaScript. | — | — |
| [no-empty-function](docs/rules/no-empty-function.md) | Mark intentional unit-bodied no-ops explicitly. | — | — |
| [no-for](docs/rules/no-for.md) | Disallow counting loops. | — | — |
| [no-mutable-record-field](docs/rules/no-mutable-record-field.md) | Disallow mutable record field declarations. | — | — |
| [no-obj-external](docs/rules/no-obj-external.md) | Disallow `@obj` externals. | — | — |
| [no-record-mutation](docs/rules/no-record-mutation.md) | Disallow record field assignment. | — | — |
| [no-restricted-modules](docs/rules/no-restricted-modules.md) | Enforce configured module, value, and type restrictions. | — | — |
| [no-top-level-side-effect](docs/rules/no-top-level-side-effect.md) | Restrict module-initialization effects outside entry modules. | — | — |
| [no-while](docs/rules/no-while.md) | Disallow `while` loops. | — | — |
| [react/button-has-type](docs/rules/react/button-has-type.md) | Declare button types explicitly. | — | — |
| [require-interface](docs/rules/require-interface.md) | Require matching implementation interfaces. | — | — |
| [require-license-header](docs/rules/require-license-header.md) | Require configured SPDX license headers. | — | — |

## License

The linter and launcher are [MIT licensed](LICENSE). The native executable also
contains third-party code under other licenses; see
[distribution details](docs/development/DISTRIBUTION.md) and the license material included
with installed packages.

## Contributing

Development setup, validation, coverage, packaging, CI, and release guidance
live in [CONTRIBUTING.md](CONTRIBUTING.md).
