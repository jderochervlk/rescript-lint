open Rescript_linter

let check expected text =
  let source =
    Source.{ filename = "console.res"; kind = Implementation; text }
  in
  match Parser.parse source with
  | Error error -> Error (Lint_error.render error)
  | Ok document ->
      let findings =
        Banned_api.check ~rules:[ No_console.rule ] ~source document
      in
      if List.length findings = expected then Ok ()
      else Error "unexpected console findings"

let () =
  Rule_test_runner.run
    [
      ( "console methods",
        check 3 "Console.log(1)\nConsole.warn(2)\nConsole.error(3)" );
      ("ordinary value", check 0 "let value = 1");
      ( "shadowed console",
        check 0 "module Console = {let log = x => x}\nConsole.log(1)" );
    ]
