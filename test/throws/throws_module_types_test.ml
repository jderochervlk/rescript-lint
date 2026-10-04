open Rescript_linter

type expected = Clean | Calls of (string * string) list | Analysis of string

let contains text fragment =
  let rec loop offset =
    offset + String.length fragment <= String.length text
    && (String.sub text offset (String.length fragment) = fragment
       || loop (offset + 1))
  in
  loop 0

let options ?root ?(dependencies = []) () =
  let options =
    { Project_options.default with root; throws_dependencies = dependencies }
  in
  List.fold_left
    (fun config (rule : Rule_config.rule) ->
      Result.bind config (fun config ->
          Rule_config.set config ~id:rule.id
            ~enabled:(rule.id = "no-unhandled-throws")))
    (Ok (Rule_config.with_options options Rule_config.default))
    Rule_config.rules

let check_result source expected result =
  let call (diagnostic : Diagnostic.t) =
    let first = diagnostic.range.start.byte_offset in
    let last = diagnostic.range.finish.byte_offset in
    if
      diagnostic.rule <> "no-unhandled-throws"
      || diagnostic.filename <> source.Source.filename
      || diagnostic.fixes <> [] || first < 0
      || last > String.length source.text
      || first > last
    then None
    else
      let reference = String.sub source.text first (last - first) in
      List.find_opt
        (fun (callee, missing) ->
          reference = callee
          && diagnostic.message
             = "Handle " ^ missing ^ " when calling " ^ callee
               ^ ". Use try/catch or switch exception patterns; caller \
                  annotations do not handle exceptions.")
        (match expected with Calls values -> values | _ -> [])
  in
  match (expected, result) with
  | Clean, Ok [] -> Ok ()
  | Calls wanted, Ok diagnostics
    when List.map call diagnostics = List.map Option.some wanted ->
      Ok ()
  | Analysis fragment, Error (Lint_error.Analysis_errors (first, rest))
    when List.for_all
           (fun (diagnostic : Diagnostic.t) ->
             diagnostic.rule = "throws-analysis" && diagnostic.fixes = [])
           (first :: rest)
         && List.exists
              (fun (diagnostic : Diagnostic.t) ->
                contains diagnostic.message fragment)
              (first :: rest) ->
      Ok ()
  | _, Error error -> Error (Lint_error.render error)
  | _, Ok diagnostics ->
      Error (String.concat " | " (List.map Diagnostic.render diagnostics))

let check_source ?root ?dependencies source expected =
  Result.bind (options ?root ?dependencies ()) (fun config ->
      check_result source expected (Linter.lint_source_with_rules config source))

let check ?(kind = Source.Implementation) text expected =
  let filename =
    if kind = Source.Implementation then "types.res" else "types.resi"
  in
  check_source Source.{ filename; kind; text } expected

let any = "unknown exceptions (a catch-all is required)"
let contract = "module type S = {@throws let run: unit => int}\n"
let implementation = "module A: S = {let run = () => 1}\n"
let active = "@throws let activate = () => 0\n"

let constrained_functor =
  "module Factory: {module Api: {@throws let run: unit => int}} = {\n\
   module Make = (Input: {}) => {let run = () => 0}\n\
   module Api = Make({})\n\
   }"

let source_checks =
  [
    ( "alias template captures before nested type shadow",
      check
        (contract
       ^ "module type Captured = S\n\
          module Inner = {module type S = {let run: unit => int}\n\
          module A: Captured = {let run = () => 0}\n\
          let value = A.run()}")
        (Calls [ ("A.run", any) ]) );
    ( "abstract inner type never falls back to outer template",
      check ~kind:Interface
        (contract ^ "module Inner: {module type S\nmodule A: S}")
        (Analysis "Cannot resolve this module type") );
    ( "active constrained functor body remains unsupported",
      check constrained_functor (Analysis "functor") );
    ( "named signature contracts",
      check (contract ^ implementation ^ "A.run()") (Calls [ ("A.run", any) ])
    );
    ( "catchall handles named signature",
      check (contract ^ implementation ^ "try A.run() catch {| _ => 0}") Clean
    );
    ( "named handler insufficient for bare signature",
      check
        (contract ^ implementation ^ "try A.run() catch {| Not_found => 0}")
        (Calls [ ("A.run", any) ]) );
    ( "named aliases chain",
      check
        (contract
       ^ "module type T = S\n\
          module type U = T\n\
          module A: U = {let run = () => 1}\n\
          A.run()")
        (Calls [ ("A.run", any) ]) );
    ( "inline constraint",
      check
        "module A: {@throws let run: unit => int} = {let run = () => 1}\n\
         A.run()"
        (Calls [ ("A.run", any) ]) );
    ( "known lexical exception",
      check
        "exception E\n\
         module type S = {@throws(E) let run: unit => int}\n\
         module A: S = {let run = () => 1}\n\
         try A.run() catch {| E => 0}"
        Clean );
    ( "lexical exception captured before shadow",
      check
        "exception E\n\
         module type S = {@throws(E) let run: unit => int}\n\
         module Inner = {exception E\n\
         module A: S = {let run = () => 1}\n\
         let value = try A.run() catch {| E => 0}}"
        (Calls [ ("A.run", "E") ]) );
    ( "lexical module type shadow",
      check
        (contract
       ^ "module Inner = {module type S = {let run: unit => int}\n\
          module A: S = {let run = () => 1}\n\
          let value = A.run()}\n" ^ implementation ^ "A.run()")
        (Calls [ ("A.run", any) ]) );
    ( "module and module type distinct namespaces",
      check
        (contract ^ "module S = {let value = 1}\n" ^ implementation ^ "A.run()")
        (Calls [ ("A.run", any) ]) );
    ( "qualified module type",
      check
        "module Types = {module type S = {@throws let run: unit => int}}\n\
         module A: Types.S = {let run = () => 1}\n\
         A.run()"
        (Calls [ ("A.run", any) ]) );
    ( "opened module type",
      check
        "module Types = {module type S = {@throws let run: unit => int}}\n\
         open Types\n\
         module A: S = {let run = () => 1}\n\
         A.run()"
        (Calls [ ("A.run", any) ]) );
    ( "included module type",
      check
        "module Types = {module type S = {@throws let run: unit => int}}\n\
         module More = {include Types}\n\
         module A: More.S = {let run = () => 1}\n\
         A.run()"
        (Calls [ ("A.run", any) ]) );
    ( "module alias exports module type",
      check
        "module Types = {module type S = {@throws let run: unit => int}}\n\
         module Alias = Types\n\
         module A: Alias.S = {let run = () => 1}\n\
         A.run()"
        (Calls [ ("A.run", any) ]) );
    ( "ambient module types not exported",
      check
        (contract ^ "module Empty = {}\nmodule A: Empty.S = {let run = () => 1}")
        (Analysis "Cannot resolve this module type") );
    ( "opened module types not exported",
      check
        "module Types = {module type S = {@throws let run: unit => int}}\n\
         module Empty = {open Types}\n\
         module A: Empty.S = {let run = () => 1}"
        (Analysis "Cannot resolve this module type") );
    ( "unknown module type",
      check
        (active ^ "module A: Unknown = {}")
        (Analysis "Cannot resolve this module type") );
    ( "abstract module type",
      check ~kind:Interface "@throws let run: unit => int\nmodule type S"
        (Analysis "Abstract module types") );
    ( "fresh template exception rejected",
      check
        "module type S = {exception E\n\
         @throws(E) let run: unit => int}\n\
         module A: S = {exception E\n\
         let run = () => 1}\n\
         module B: S = {exception E\n\
         let run = () => 1}\n\
         try A.run() catch {| B.E => 0}"
        (Analysis "per-module constructor identities") );
    ( "nested fresh exception rejected",
      check
        "module type S = {module Nested: {exception E\n\
         @throws(E) let run: unit => int}}\n\
         module A: S = {}"
        (Analysis "per-module constructor identities") );
    ( "fresh inline constraint exception rejected",
      check
        "module A: {exception E\n\
         @throws(E) let run: unit => int} = {exception E\n\
         let run = () => 1}"
        (Analysis "per-module constructor identities") );
    ( "type of existing exception rejected conservatively",
      check
        "module Original = {exception E\n\
         @throws(E) let run = () => 1}\n\
         module type S = module type of Original"
        (Analysis "per-module constructor identities") );
    ( "module type of known values",
      check
        "module Original = {@throws let run = () => 1}\n\
         module type S = module type of Original\n\
         module A: S = {let run = () => 1}\n\
         A.run()"
        (Calls [ ("A.run", any) ]) );
    ( "signature authoritative unannotated",
      check
        "module A: {let run: unit => int} = {@throws let run = () => 1}\n\
         A.run()"
        Clean );
    ( "signature hides private value",
      check
        "module A: {let visible: unit => int} = {@throws let hidden = () => 1\n\
         let visible = () => 0}\n\
         A.hidden()"
        (Analysis "Cannot resolve A.hidden") );
    ( "constrained body still analyzed locally",
      check
        "module A: {let value: int} = {@throws let hidden = () => 1\n\
         let value = hidden()}"
        (Calls [ ("hidden", any) ]) );
    ( "constrained function body remains own context",
      check
        "module A: {let run: unit => int} = {@throws let hidden = () => 1\n\
         let run = () => hidden()}"
        (Calls [ ("hidden", any) ]) );
    ( "constraint implementation lexical annotation unchanged",
      check
        "module A: {@throws let run: unit => int} = {let run = () => 1\n\
         let value = run()}\n\
         A.run()"
        (Calls [ ("A.run", any) ]) );
    ( "nested constraints",
      check
        "module A: {@throws let run: unit => int} = ({let run = () => 0}: {let \
         run: unit => int})\n\
         A.run()"
        (Calls [ ("A.run", any) ]) );
    ( "module type signature include",
      check ~kind:Interface (contract ^ "include S") Clean );
    ( "module type signature module",
      check ~kind:Interface (contract ^ "module A: S") Clean );
    ( "with substitution remains unsupported",
      check
        (active
       ^ "module type S = {type t}\n\
          module A: S with type t = int = {type t = int}")
        (Analysis "module type cannot") );
    ( "functor module type remains unsupported",
      check
        (active ^ "module type S = (X: {}) => {}")
        (Analysis "module type cannot") );
    ( "default inactive file unchanged",
      check "module type S = Unknown\nmodule A: S = {}" Clean );
  ]

let write filename contents =
  Out_channel.with_open_bin filename (fun channel ->
      output_string channel contents)

let rec remove path =
  if (Unix.lstat path).st_kind = Unix.S_DIR then (
    Array.iter
      (fun name -> remove (Filename.concat path name))
      (Sys.readdir path);
    Unix.rmdir path)
  else Sys.remove path

let write_files directory files =
  List.iter
    (fun (name, contents) -> write (Filename.concat directory name) contents)
    files

let write_package root (name, config, files) =
  let directory = Filename.concat root name in
  Unix.mkdir directory 0o700;
  write (Filename.concat directory "rescript.json") config;
  write_files directory files;
  directory

let project ?(packages = []) files text expected =
  try
    let root = Filename.temp_file "throws-module-types-" "" in
    Sys.remove root;
    Unix.mkdir root 0o700;
    Fun.protect
      ~finally:(fun () -> remove root)
      (fun () ->
        Unix.mkdir (Filename.concat root "src") 0o700;
        write (Filename.concat root "rescript.json") "{\"sources\":\"src\"}";
        write_files (Filename.concat root "src") files;
        let dependencies = List.map (write_package root) packages in
        check_source ~root ~dependencies
          Source.
            {
              filename = Filename.concat root "src/Main.res";
              text;
              kind = Implementation;
            }
          expected)
  with
  | Sys_error message -> Error message
  | Unix.Unix_error (error, operation, path) ->
      Error (operation ^ " " ^ path ^ ": " ^ Unix.error_message error)

let project_checks =
  [
    ( "package-exported templates follow cross-package exception remapping",
      project
        ~packages:
          [
            ( "z-errors",
              "{\"name\":\"errors\",\"namespace\":\"Errors\",\"sources\":\".\"}",
              [
                ( "Api.res",
                  "exception E\n\
                   module type S = {@throws(E) let run: unit => int}" );
                ( "Api.resi",
                  "// public identity\n\
                   exception E\n\
                   module type S = {@throws(E) let run: unit => int}" );
              ] );
            ( "a-facade",
              "{\"name\":\"facade\",\"namespace\":\"Facade\",\"sources\":\".\",\"dependencies\":[\"errors\"]}",
              [
                ( "Api.res",
                  "exception E = Errors.Api.E\nmodule type S = Errors.Api.S" );
                ("Api.resi", "exception E\nmodule type S = Errors.Api.S");
              ] );
          ]
        []
        "module A: Facade.Api.S = {let run = () => 0}\n\
         A.run()\n\
         try A.run() catch {| Errors.Api.E => 0}\n\
         try A.run() catch {| Facade.Api.E => 0}"
        (Calls [ ("A.run", "E") ]) );
    ( "provider declared contract does not infer functor results",
      project
        [ ("Provider.res", constrained_functor) ]
        "Provider.Factory.Api.run()"
        (Calls [ ("Provider.Factory.Api.run", any) ]) );
    ( "cross-file template activation",
      project
        [
          ("Types.res", contract);
          ("Api.res", "module A: Types.S = {let run = () => 0}");
        ]
        "Api.A.run()"
        (Calls [ ("Api.A.run", any) ]) );
    ( "interface named module contract",
      project
        [ ("Types.resi", contract); ("Api.resi", "module A: Types.S") ]
        "Api.A.run()"
        (Calls [ ("Api.A.run", any) ]) );
    ( "interface named include",
      project
        [ ("Types.resi", contract); ("Api.resi", "include Types.S") ]
        "Api.run()"
        (Calls [ ("Api.run", any) ]) );
    ( "interface public module type",
      project
        [
          ("Types.res", "module type S = {let run: unit => int}");
          ("Types.resi", contract);
          ("Api.resi", "module A: Types.S");
        ]
        "Api.A.run()"
        (Calls [ ("Api.A.run", any) ]) );
    ( "interface hides module type",
      project
        [
          ("Types.res", contract ^ "let visible = 1");
          ("Types.resi", "let visible: int");
          ("Api.resi", "module A: Types.S");
        ]
        (active ^ "Api.A.run()") (Analysis "Cannot resolve this module type") );
    ( "reverse lexical dependency aliases",
      project
        [
          ("A.resi", "module type S = Z.S");
          ("Z.resi", contract);
          ("Api.resi", "module R: A.S");
        ]
        "Api.R.run()"
        (Calls [ ("Api.R.run", any) ]) );
    ( "cross-file existing exception preserved",
      project
        [
          ("Errors.resi", "exception E");
          ( "Types.resi",
            "module type S = {@throws(Errors.E) let run: unit => int}" );
          ("Api.resi", "module A: Types.S");
        ]
        "try Api.A.run() catch {| Errors.E => 0}" Clean );
    ( "implementation interface exception remap in template",
      project
        [
          ( "Errors.res",
            "exception E\nmodule type S = {@throws(E) let run: unit => int}" );
          ( "Errors.resi",
            "exception E\nmodule type S = {@throws(E) let run: unit => int}" );
          ("Api.res", "module A: Errors.S = {let run = () => 0}");
        ]
        "try Api.A.run() catch {| Errors.E => 0}" Clean );
    ( "constrained provider hidden metadata ignored",
      project
        [
          ( "Api.res",
            "module A: {@throws let run: unit => int} = {@throws(42) let \
             hidden = () => 1\n\
             let run = () => 0}" );
        ]
        "try Api.A.run() catch {| _ => 0}" Clean );
    ( "constrained provider hidden placement ignored",
      project
        [
          ( "Api.res",
            "module A: {@throws let run: unit => int} = {@@throws\n\
             let run = () => 0}" );
        ]
        "try Api.A.run() catch {| _ => 0}" Clean );
    ( "public constraint signature overrides implementation",
      project
        [
          ( "Api.res",
            "module A: {let run: unit => int} = {@throws let run = () => 0}" );
        ]
        "Api.A.run()" Clean );
    ( "nested signature named type",
      project
        [
          ("Types.resi", contract);
          ("Api.resi", "module Nested: {module A: Types.S}");
        ]
        "Api.Nested.A.run()"
        (Calls [ ("Api.Nested.A.run", any) ]) );
    ( "cyclic named aliases explicit failure",
      project
        [
          ("A.resi", "module type S = B.S\n@throws let activate: unit => int");
          ("B.resi", "module type S = A.S");
          ("Api.resi", "module R: A.S");
        ]
        "Api.R.run()" (Analysis "Cannot resolve this module type") );
  ]

let () =
  let failures =
    source_checks @ project_checks
    |> List.filter_map (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
