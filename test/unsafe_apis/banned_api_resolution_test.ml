open Rescript_linter

type expected = { rule : string; message : string; reference : string }

let console canonical reference =
  { rule = "no-console"; message = "Do not use " ^ canonical ^ "."; reference }

let magic canonical reference =
  {
    rule = "no-object-magic";
    message =
      "Do not use " ^ canonical
      ^ ". Use a typed conversion or validate the input.";
    reference;
  }

let unsafe canonical reference =
  {
    rule = "no-unsafe";
    message =
      "Do not use " ^ canonical
      ^ ". Use a checked API or explicit pattern matching.";
    reference;
  }

let config ?root () =
  let initial =
    Rule_config.with_options
      { Project_options.default with root }
      Rule_config.default
  in
  List.fold_left
    (fun result (rule : Rule_config.rule) ->
      Result.bind result (fun config ->
          Rule_config.set config ~id:rule.id
            ~enabled:
              (List.mem rule.id
                 [ "no-console"; "no-object-magic"; "no-unsafe" ])))
    (Ok initial) Rule_config.rules

let actual (source : Source.t) (finding : Diagnostic.t) =
  let start = finding.range.start.byte_offset in
  let finish = finding.range.finish.byte_offset in
  if
    finding.filename = source.filename
    && finding.fixes = [] && start >= 0 && finish >= start
    && finish <= String.length source.text
  then
    Some
      {
        rule = finding.rule;
        message = finding.message;
        reference = String.sub source.text start (finish - start);
      }
  else None

let findings ?root source =
  Result.bind (config ?root ()) (fun config ->
      Result.map_error Lint_error.render
        (Linter.lint_source_with_rules config source))

let check_source ?root source expected =
  Result.bind (findings ?root source) (fun findings ->
      if List.map (actual source) findings = List.map Option.some expected then
        Ok ()
      else
        Error
          ("Unexpected findings: "
          ^ String.concat " | " (List.map Diagnostic.render findings)))

let check ?(kind = Source.Implementation) text expected =
  check_source Source.{ filename = "resolution.res"; text; kind } expected

let clean text = check text []

let alias_checks =
  [
    ( "console module alias",
      check "module C = Console\nC.log(1)" [ console "Console.log" "C.log" ] );
    ( "magic module alias",
      check "module O = Obj\nO.magic(1)" [ magic "Obj.magic" "O.magic" ] );
    ( "unsafe module alias",
      check "module O = Option\nO.getUnsafe(None)"
        [ unsafe "Option.getUnsafe" "O.getUnsafe" ] );
    ( "module alias chain",
      check "module A = Obj\nmodule B = A\nmodule C = B\nC.magic(1)"
        [ magic "Obj.magic" "C.magic" ] );
    ( "nested runtime namespace alias",
      check "module J = Js\nmodule C = J.Console\nC.warn(1)"
        [ console "Js.Console.warn" "C.warn" ] );
    ( "captured module survives target shadow",
      check "module C = Console\nmodule Console = Other\nC.log(1)"
        [ console "Console.log" "C.log" ] );
    ( "module initializer sees previous binding",
      check "module C = Console\nmodule C = {let value = C.log(1)}"
        [ console "Console.log" "C.log" ] );
    ( "console value capture reported once",
      check "module C = Console\nlet log = C.log\nlog(1)\nlog(2)"
        [ console "Console.log" "C.log" ] );
    ( "magic value capture reported once",
      check "module O = Obj\nlet cast = O.magic\ncast(1)"
        [ magic "Obj.magic" "O.magic" ] );
    ( "unsafe value capture reported once",
      check "module O = Option\nlet get = O.getUnsafe\nget(None)"
        [ unsafe "Option.getUnsafe" "O.getUnsafe" ] );
  ]

let open_checks =
  [
    ( "console open",
      check "open Console\nlog(1)" [ console "Console.log" "log" ] );
    ("magic open", check "open Obj\nmagic(1)" [ magic "Obj.magic" "magic" ]);
    ( "unsafe open",
      check "open Option\ngetUnsafe(None)"
        [ unsafe "Option.getUnsafe" "getUnsafe" ] );
    ( "console include",
      check "include Console\nlog(1)" [ console "Console.log" "log" ] );
    ( "magic include",
      check "include Obj\nmagic(1)" [ magic "Obj.magic" "magic" ] );
    ( "unsafe include",
      check "include Option\ngetUnsafe(None)"
        [ unsafe "Option.getUnsafe" "getUnsafe" ] );
    ( "block-local open",
      check "let run = () => {open Console; log(1)}\nlog(2)"
        [ console "Console.log" "log" ] );
    ( "known empty open preserves imported value",
      check "module Empty = {}\nopen Console\nopen Empty\nlog(1)"
        [ console "Console.log" "log" ] );
    ( "later known open shadows imported value",
      clean
        "module Local = {let log = x => x}\nopen Console\nopen Local\nlog(1)" );
    ( "safe runtime open shadows console log",
      clean "open Console\nopen Js.Math\nlog(1.0)" );
    ( "later console open shadows math log",
      check "open Js.Math\nopen Console\nlog(1.0)"
        [ console "Console.log" "log" ] );
    ( "known empty open preserves captured module",
      check "module C = Console\nmodule Empty = {}\nopen Empty\nC.log(1)"
        [ console "Console.log" "C.log" ] );
  ]

let shadow_checks =
  [
    ( "value binding shadows opened API",
      clean "open Console\nlet log = x => x\nlog(1)" );
    ( "value initializer still sees opened API",
      check "open Console\nlet log = log\nlog(1)"
        [ console "Console.log" "log" ] );
    ( "function parameter shadows opened API",
      clean "open Console\nlet run = log => log(1)" );
    ( "tuple pattern shadows opened APIs",
      clean
        "open Obj\n\
         open Option\n\
         let run = ((magic, getUnsafe)) => magic(getUnsafe(None))" );
    ( "record pattern shadows opened API",
      clean "open Console\nlet run = ({log}) => log(1)" );
    ( "switch pattern shadows opened API",
      clean "open Console\nswitch value {| Some(log) => log(1) | None => 0}" );
    ( "catch pattern shadows opened API",
      clean "open Console\ntry 0 catch {| log => log(1)}" );
    ( "recursive value shadows opened API in its body",
      clean "open Console\nlet rec log = x => log(x)" );
    ( "block module shadow stays local",
      check
        "module C = Console\n\
         let run = () => {module C = Other; C.log(1)}\n\
         C.log(2)"
        [ console "Console.log" "C.log" ] );
    ( "functor parameter shadows module alias",
      clean
        "module C = Console\n\
         module F = (C: {let log: int => int}) => {let value = C.log(1)}" );
    ( "recursive module shadows alias in its initializer",
      clean
        "module C = Console\n\
         module rec C: {let log: int => int} = {let log = x => C.log(x)}" );
  ]

let export_checks =
  [
    ( "nested module exports explicit runtime alias",
      check "module Local = {module C = Console}\nLocal.C.log(1)"
        [ console "Console.log" "Local.C.log" ] );
    ( "nested include reexports API",
      check "module Local = {include Console}\nLocal.log(1)"
        [ console "Console.log" "Local.log" ] );
    ( "nested open does not export opened values",
      clean "module Local = {open Console; let value = 0}\nLocal.log(1)" );
    ( "nested module does not export ambient opened values",
      clean "open Console\nmodule Local = {let value = 0}\nLocal.log(1)" );
    ( "nested module does not export ambient module aliases",
      clean "module C = Console\nmodule Local = {let value = 0}\nLocal.C.log(1)"
    );
    ( "module alias to unknown module stays unknown",
      clean "module C = Other\nC.log(1)\nC.magic(1)\nC.getUnsafe(None)" );
    ( "unknown open obscures earlier imported value",
      clean "open Console\nopen Other\nlog(1)" );
    ( "unknown include obscures earlier imported value",
      clean "open Option\ninclude Other\ngetUnsafe(None)" );
    ( "unknown open obscures canonical runtime roots",
      clean "open Other\nConsole.log(1)\nObj.magic(1)\nOption.getUnsafe(None)"
    );
    ( "unknown include obscures captured module",
      clean "module C = Console\ninclude Other\nC.log(1)" );
    ( "standalone attribute payload does not execute",
      clean "@@example(Console.log(1))\n@@example(Obj.magic(1))" );
    ( "interface does not execute annotated examples",
      check ~kind:Source.Interface
        "@@example(Console.log(1))\nmodule C = Console\nlet value: int" [] );
  ]

let exact_alias_range =
  let source =
    Source.
      {
        filename = "resolution.res";
        text = "module C = Console\n  C.log(1)\n";
        kind = Implementation;
      }
  in
  Result.bind (findings source) (function
    | [ finding ]
      when (finding.range
           = Diagnostic.
               {
                 start = { line = 2; column = 3; byte_offset = 21 };
                 finish = { line = 2; column = 8; byte_offset = 26 };
               })
           && actual source finding = Some (console "Console.log" "C.log") ->
        Ok ()
    | _ -> Error "Alias diagnostic did not retain its exact source range")

let constraint_checks =
  [
    ( "earlier include does not resolve a later runtime shadow",
      clean
        "module Original = {module C = {let log = x => x}}\n\
         module Facade = {include Original; module Original = {module C = \
         Stdlib.Console}}\n\
         Facade.C.log(1)" );
    ( "earlier runtime include survives a later safe shadow",
      check
        "module Original = {module C = Stdlib.Console}\n\
         module Facade = {include Original; module Original = {module C = {let \
         log = x => x}}}\n\
         Facade.C.log(1)"
        [ console "Stdlib.Console.log" "Facade.C.log" ] );
    ( "inline signature preserves exposed nested module identity",
      check
        "module Facade: {module C: {let log: int => unit}} = {module C = \
         Console}\n\
         Facade.C.log(1)"
        [ console "Console.log" "Facade.C.log" ] );
    ( "inline signature hides unexposed nested members",
      check
        "module Facade: {module C: {let log: int => unit}} = {module C = \
         Console}\n\
         Facade.C.warn(1)\n\
         Facade.C.log(2)"
        [ console "Console.log" "Facade.C.log" ] );
    ( "inline signature hides unexposed module aliases",
      clean
        "module Facade: {let value: int} = {module C = Console; let value = 1}\n\
         Facade.C.log(1)" );
  ]

let write filename text =
  Out_channel.with_open_bin filename (fun channel -> output_string channel text)

let rec remove path =
  if (Unix.lstat path).st_kind = Unix.S_DIR then (
    Array.iter
      (fun name -> remove (Filename.concat path name))
      (Sys.readdir path);
    Unix.rmdir path)
  else Sys.remove path

let temporary run =
  try
    let root = Filename.temp_file "banned-resolution-" "" in
    Sys.remove root;
    Unix.mkdir root 0o700;
    Fun.protect ~finally:(fun () -> remove root) (fun () -> run root)
  with
  | Sys_error message -> Error ("Fixture I/O failed: " ^ message)
  | Unix.Unix_error (error, operation, path) ->
      Error (operation ^ " " ^ path ^ ": " ^ Unix.error_message error)

let project_check files text expected =
  temporary (fun root ->
      Unix.mkdir (Filename.concat root "src") 0o700;
      write (Filename.concat root "rescript.json") "{\"sources\":\"src\"}";
      List.iter
        (fun (name, text) -> write (Filename.concat root ("src/" ^ name)) text)
        files;
      check_source ~root
        Source.
          {
            filename = Filename.concat root "src/Main.res";
            text;
            kind = Implementation;
          }
        expected)

let project_checks =
  [
    ( "project Console shadows runtime",
      project_check
        [ ("Console.res", "let log = x => x") ]
        "Console.log(1)\nmodule C = Console\nC.log(2)" [] );
    ( "project Obj shadows runtime",
      project_check
        [ ("Obj.res", "let magic = x => x") ]
        "Obj.magic(1)\nmodule O = Obj\nO.magic(2)" [] );
    ( "project Option shadows only its runtime root",
      project_check
        [ ("Option.res", "let getUnsafe = x => x") ]
        "Option.getUnsafe(None)\nStdlib.Option.getUnsafe(None)"
        [ unsafe "Stdlib.Option.getUnsafe" "Stdlib.Option.getUnsafe" ] );
    ( "project function alias inference remains outside this rule",
      project_check [ ("Api.res", "let log = Console.log") ] "Api.log(1)" [] );
  ]

let () =
  let failures =
    alias_checks @ open_checks @ shadow_checks @ export_checks @ project_checks
    @ constraint_checks
    @ [ ("exact alias source range", exact_alias_range) ]
    |> List.filter_map (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
