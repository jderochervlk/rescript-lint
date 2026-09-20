The CLI exposes its version and rejects unsupported requests.

  $ rescript-lint --help
  Usage: rescript-lint [--] FILE.res [FILE.resi ...]
  
  Options:
    -h, --help     Show this help
    --version      Show the version
    --             Treat remaining arguments as file paths
  

  $ rescript-lint --version
  0.1.0-dev

  $ rescript-lint
  No input files. Use --help for usage.
  [2]

  $ rescript-lint --wat
  Unknown option: --wat
  [2]

  $ rescript-lint fixtures/example.res

  $ rescript-lint fixtures/example.resi

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
