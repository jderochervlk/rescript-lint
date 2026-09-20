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
