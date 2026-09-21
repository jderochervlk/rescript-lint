The CLI exposes its version and rejects unsupported requests.

  $ rescript-lint --help
  Usage: rescript-lint [--fix] [--watch] [--] FILE.res [FILE.resi ...]
         rescript-lint lsp --stdio
  
  Options:
    --format human|json  Select diagnostic output (default: human)
    -h, --help     Show this help
    --version      Show the version
    --fix          Apply safe fixes, then report remaining errors
    -w, --watch    Re-run when an input file changes
    --list-rules   List rules and their default activation
    --enable-rule ID   Enable a rule (repeatable)
    --disable-rule ID  Disable a rule (repeatable)
    --config FILE  Read rule and project options from JSON
    --project DIR  Read project sources and interfaces
    --jsx-runtime react-dom  Select the React DOM adapter
    --test-framework rescript-vitest-3  Select the test adapter
    --throws-runtime rescript-12.3.1  Select the throws runtime adapter
    --             Treat remaining arguments as file paths
  

  $ rescript-lint --version
  0.1.0-beta.1

  $ rescript-lint
  No input files. Use --help for usage.
  [2]

  $ rescript-lint --wat
  Unknown option: --wat
  [2]

  $ rescript-lint lsp
  Usage: rescript-lint lsp --stdio
  [2]

  $ rescript-lint fixtures/example.res

  $ rescript-lint fixtures/example.resi

Rule activation uses exact IDs and preserves parse and analysis failures.

  $ rescript-lint --list-rules | wc -l | tr -d ' '
  105
  $ rescript-lint --list-rules | grep '^no-empty-function '
  no-empty-function (disabled)
  $ rescript-lint --disable-rule no-console fixtures/console.res
  $ rescript-lint --enable-rule typo fixtures/example.res
  Unknown rule: typo
  [2]
  $ rescript-lint --enable-rule
  --enable-rule requires a rule ID.
  [2]
  $ rescript-lint --disable-rule --fix fixtures/example.res
  --disable-rule requires a rule ID.
  [2]
  $ rescript-lint --enable-rule no-console --disable-rule no-console fixtures/console.res
  $ rescript-lint fixtures/optional_rules.res
  $ rescript-lint --enable-rule simplify-boolean-expression fixtures/optional_rules.res
  fixtures/optional_rules.res:1:13: error [simplify-boolean-expression] This boolean expression can be simplified.
  [1]
  $ rescript-lint fixtures/empty_function.res
  $ rescript-lint --enable-rule no-empty-function fixtures/empty_function.res
  fixtures/empty_function.res:1:12: error [no-empty-function] This function has an empty body; annotate an intentional no-op with a unit return type.
  [1]

Disabling a fixable rule prevents writes, and enabled optional findings survive fixes.

  $ cp fixtures/spacing.res disabled-fix.res
  $ rescript-lint --fix --disable-rule blank-lines disabled-fix.res
  $ cmp disabled-fix.res fixtures/spacing.res
  $ cp fixtures/optional_rules.res optional-fix.res
  $ rescript-lint --fix --enable-rule simplify-boolean-expression optional-fix.res
  optional-fix.res:1:13: error [simplify-boolean-expression] This boolean expression can be simplified.
  [1]
  $ cmp optional-fix.res fixtures/optional_rules.res

Debugger expressions and rethrow-only catches are default errors.

  $ rescript-lint fixtures/new_rules.res
  fixtures/new_rules.res:1:1: error [no-debugger] Remove this debugger expression.
  fixtures/new_rules.res:3:17: error [no-useless-catch] This catch only rethrows the original exception.
  [1]
  $ rescript-lint --disable-rule no-debugger --disable-rule no-useless-catch fixtures/new_rules.res

Rule selection survives editor changes and watch reruns, including fix mode.

  $ bash rule_modes_cli.sh
  LSP optional rule survives unsaved document changes.
  Watch lint retains the optional rule after a file change.
  Watch fix retains the optional rule after a file change.

The language-server subcommand speaks framed JSON-RPC only on stdout.

  $ bash lsp_cli.sh
  "positionEncoding":"utf-16"
  "serverInfo":{"name":"rescript-lint","version":"0.1.0-beta.1"}
  "id":2,"jsonrpc":"2.0","result":null

Watch mode reruns after changes and exits conventionally for termination signals.

  $ cp fixtures/example.res watched.res
  $ bash watch_cli.sh INT watched.res watch-int.err yes no
  $ cat watch-int.err
  Watching 1 file(s). Press Ctrl+C to stop.
  Change detected. Re-running lint.
  $ cp fixtures/spacing.res watched-fix.res
  $ chmod u+w watched-fix.res
  $ bash watch_cli.sh TERM watched-fix.res watch-term.err no yes
  $ cat watch-term.err
  Watching 1 file(s). Press Ctrl+C to stop.
  $ rescript-lint watched-fix.res

Qualified console references fail the lint check.

  $ rescript-lint fixtures/console.res
  fixtures/console.res:1:1: error [no-console] Do not use Console.log.
  fixtures/console.res:2:12: error [no-console] Do not use Js.Console.warn.
  fixtures/console.res:3:5: error [no-console] Do not use Console.log.
  [1]

Unchecked casts fail alongside console references, in source order.

  $ rescript-lint fixtures/object_magic.res
  fixtures/object_magic.res:1:12: error [no-object-magic] Do not use Obj.magic. Use a typed conversion or validate the input.
  fixtures/object_magic.res:2:17: error [no-object-magic] Do not use Obj.magic. Use a typed conversion or validate the input.
  fixtures/object_magic.res:3:1: error [no-console] Do not use Console.log.
  fixtures/object_magic.res:3:1: error [blank-lines] Separate these declarations or statements with a blank line.
  fixtures/object_magic.res:3:13: error [no-object-magic] Do not use Obj.magic. Use a typed conversion or validate the input.
  [1]

Unsafe APIs fail for absent and present values, including inside handlers.

  $ rescript-lint fixtures/unsafe.res
  fixtures/unsafe.res:1:1: error [no-unsafe] Do not use Option.getUnsafe. Use a checked API or explicit pattern matching.
  fixtures/unsafe.res:2:1: error [no-unsafe] Do not use Option.getUnsafe. Use a checked API or explicit pattern matching.
  fixtures/unsafe.res:3:5: error [no-unsafe] Do not use Belt.Option.getUnsafe. Use a checked API or explicit pattern matching.
  fixtures/unsafe.res:4:1: error [no-console] Do not use Console.log.
  fixtures/unsafe.res:4:13: error [no-object-magic] Do not use Obj.magic. Use a typed conversion or validate the input.
  fixtures/unsafe.res:4:23: error [no-unsafe] Do not use Array.getUnsafe. Use a checked API or explicit pattern matching.
  [1]

Hooks require valid function context and unconditional placement.

  $ rescript-lint fixtures/hooks_clean.res

  $ rescript-lint fixtures/hooks.res
  fixtures/hooks.res:1:1: error [react/rules-of-hooks] Call hooks only at the top level of a React component or custom hook.
  fixtures/hooks.res:6:5: error [react/rules-of-hooks] Do not call hooks conditionally.
  fixtures/hooks.res:8:23: error [react/rules-of-hooks] Call hooks only at the top level of a React component or custom hook.
  fixtures/hooks.res:13:7: error [react/rules-of-hooks] Do not call hooks in try/catch or exception-handling switches.
  [1]

Annotated calls require actual handling, not propagation annotations.

  $ rescript-lint fixtures/throws_clean.res

  $ rescript-lint fixtures/throws.res
  fixtures/throws.res:4:1: error [no-unhandled-throws] Handle Not_found when calling read. Use try/catch or switch exception patterns; caller annotations do not handle exceptions.
  fixtures/throws.res:7:20: error [no-unhandled-throws] Handle Not_found when calling read. Use try/catch or switch exception patterns; caller annotations do not handle exceptions.
  [1]

Unsupported annotated analysis fails explicitly, without stopping later files.

  $ rescript-lint fixtures/throws_unsupported.res fixtures/throws.res 2>&1
  fixtures/throws.res:4:1: error [no-unhandled-throws] Handle Not_found when calling read. Use try/catch or switch exception patterns; caller annotations do not handle exceptions.
  fixtures/throws.res:7:20: error [no-unhandled-throws] Handle Not_found when calling read. Use try/catch or switch exception patterns; caller annotations do not handle exceptions.
  fixtures/throws_unsupported.res:1:1: error [throws-analysis] Annotated external/interface declarations need a direct synchronous function type; promise results and returned functions are not supported.
  [2]

Syntax errors fail analysis, and subsequent files are still checked.

  $ rescript-lint fixtures/invalid.res fixtures/console.res 2>&1
  fixtures/console.res:1:1: error [no-console] Do not use Console.log.
  fixtures/console.res:2:12: error [no-console] Do not use Js.Console.warn.
  fixtures/console.res:3:5: error [no-console] Do not use Console.log.
  fixtures/invalid.res:1:5: error [syntax] I was expecting a name for this let-binding. Example: `let message = "hello"`
  [2]

  $ rescript-lint example.txt
  example.txt: Expected a .res or .resi file.
  [2]

  $ rescript-lint missing.res
  missing.res: Cannot read file: missing.res: No such file or directory
  [2]

Spacing errors are fixable and fixes are idempotent.

  $ cp fixtures/spacing.res fix.res
  $ chmod u+w fix.res
  $ rescript-lint fix.res
  fix.res:2:1: error [blank-lines] Separate these declarations or statements with a blank line.
  fix.res:3:1: error [blank-lines] Separate these declarations or statements with a blank line.
  fix.res:6:1: error [blank-lines] Separate these declarations or statements with a blank line.
  [1]
  $ rescript-lint --fix fix.res
  $ sed 's/^/|/' fix.res
  |@val external read: unit => int = "read"
  |
  |let value = read()->convert
  |
  |switch value {
  || _ => consume(value)
  |}
  |
  |done()
  $ cp fix.res fixed.res
  $ rescript-lint --fix fix.res
  $ cmp fixed.res fix.res
  $ rescript-lint fix.res

Fix mode continues after errors without rewriting invalid files.

  $ cp fixtures/spacing.res fix.res
  $ cp fixtures/invalid.res invalid.res
  $ rescript-lint --fix invalid.res fix.res
  invalid.res:1:5: error [syntax] I was expecting a name for this let-binding. Example: `let message = "hello"`
  [2]
  $ cmp invalid.res fixtures/invalid.res
  $ cmp fix.res fixed.res

Nonfixable findings remain after safe spacing changes.

  $ cp fixtures/object_magic.res casts.res
  $ chmod u+w casts.res
  $ rescript-lint --fix casts.res
  casts.res:1:12: error [no-object-magic] Do not use Obj.magic. Use a typed conversion or validate the input.
  casts.res:2:17: error [no-object-magic] Do not use Obj.magic. Use a typed conversion or validate the input.
  casts.res:4:1: error [no-console] Do not use Console.log.
  casts.res:4:13: error [no-object-magic] Do not use Obj.magic. Use a typed conversion or validate the input.
  [1]

Project configuration, adapter activation, and audited suppressions.

  $ bash project_cli.sh
  Configuration discovers project sources and activates its adapter.
  Later CLI selection overrides configured activation.
  Missing adapter exits with an explicit analysis error.
  Fix mode preserves valid audited suppressions.
  Unused suppressions remain hard lint findings.
  Invalid configuration fails before linting.

Project-aware throws contracts preserve source boundaries and fail explicitly.

  $ bash project_throws_cli.sh
  Project mode checks imported throws contracts without local annotations.
  Source-only mode retains its local contract boundary.
  Configured project discovery accepts imported named exception handlers.
  Disabling throws analysis bypasses malformed imported contract metadata.
  Malformed imported metadata reports its provider location and analysis status.
  Fix mode leaves the caller unchanged when imported analysis fails.
  Public interfaces take precedence over hidden implementation annotations.

Runtime throws contracts use an explicit pinned adapter.

  $ bash runtime_throws_cli.sh
  Runtime throws contracts remain opt-in.
  The pinned runtime adapter reports each unhandled JSON call once.
  Configured runtime contracts accept catch-all handlers.
  Explicit runtime analysis fails on unavailable callable metadata.
  Disabling the throws rule bypasses the runtime adapter.
  Unknown runtime adapter versions are rejected.
  $ bash watch_discovery_cli.sh
  Project watch discovers new files and recovers from configuration errors.
