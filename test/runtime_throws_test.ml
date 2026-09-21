open Rescript_linter

type expected = Clean | Calls of string list | Analysis of int

let config ?root ?(adapter = true) ?(enabled = true) () =
  let options =
    {
      Project_options.default with
      root;
      throws_runtime = (if adapter then Some Rescript_12_3_1 else None);
    }
  in
  List.fold_left
    (fun result (rule : Rule_config.rule) ->
      Result.bind result (fun config ->
          Rule_config.set config ~id:rule.id
            ~enabled:(enabled && rule.id = "no-unhandled-throws")))
    (Ok (Rule_config.with_options options Rule_config.default))
    Rule_config.rules

let call (source : Source.t) (finding : Diagnostic.t) =
  let start = finding.range.start.byte_offset in
  let finish = finding.range.finish.byte_offset in
  if
    finding.filename <> source.filename
    || finding.fixes <> [] || start < 0 || finish < start
    || finish > String.length source.text
  then None
  else
    let reference = String.sub source.text start (finish - start) in
    let message =
      "Handle unknown exceptions (a catch-all is required) when calling "
      ^ reference
      ^ ". Use try/catch or switch exception patterns; caller annotations do \
         not handle exceptions."
    in
    if finding.rule = "no-unhandled-throws" && finding.message = message then
      Some reference
    else None

let expect source expected result =
  match (expected, result) with
  | Clean, Ok [] -> Ok ()
  | Calls wanted, Ok findings
    when List.map (call source) findings = List.map Option.some wanted ->
      Ok ()
  | Analysis count, Error (Lint_error.Analysis_errors (first, rest))
    when List.length (first :: rest) = count
         && List.length (List.sort_uniq compare (first :: rest)) = count
         && List.for_all
              (fun (item : Diagnostic.t) ->
                item.rule = "throws-analysis"
                && item.message <> "" && item.fixes = [])
              (first :: rest) ->
      Ok ()
  | _, Error error -> Error (Lint_error.render error)
  | _, Ok findings ->
      Error
        ("Unexpected findings: "
        ^ String.concat " | " (List.map Diagnostic.render findings))

let check_source ?root ?adapter ?enabled source expected =
  Result.bind (config ?root ?adapter ?enabled ()) (fun config ->
      expect source expected (Linter.lint_source_with_rules config source))

let check ?adapter ?enabled text expected =
  check_source ?adapter ?enabled
    Source.{ filename = "runtime.res"; text; kind = Implementation }
    expected

let inventory_checks =
  List.map
    (fun (name, arguments) ->
      ( "runtime JSON contract " ^ name,
        check ("JSON." ^ name ^ arguments) (Calls [ "JSON." ^ name ]) ))
    [
      ("parseOrThrow", "(\"{}\")");
      ("parseExn", "(\"{}\")");
      ("parseExnWithReviver", "(\"{}\", (_, value) => value)");
      ("stringifyAny", "(1)");
      ("stringifyAnyWithIndent", "(1, 2)");
      ("stringifyAnyWithReplacer", "(1, (_, value) => value)");
      ("stringifyAnyWithReplacerAndIndent", "(1, (_, value) => value, 2)");
      ("stringifyAnyWithFilter", "(1, [\"key\"])");
      ("stringifyAnyWithFilterAndIndent", "(1, [\"key\"], 2)");
    ]

let resolution_checks =
  [
    ( "qualified stdlib contract",
      check "Stdlib.JSON.parseOrThrow(\"{}\")"
        (Calls [ "Stdlib.JSON.parseOrThrow" ]) );
    ( "flattened stdlib contract",
      check "Stdlib_JSON.parseOrThrow(\"{}\")"
        (Calls [ "Stdlib_JSON.parseOrThrow" ]) );
    ( "module aliases preserve runtime contracts",
      check "module J = JSON\nmodule Data = J\nData.parseOrThrow(\"{}\")"
        (Calls [ "Data.parseOrThrow" ]) );
    ( "opened runtime contract",
      check "open JSON\nparseOrThrow(\"{}\")" (Calls [ "parseOrThrow" ]) );
    ( "included runtime contract",
      check "include JSON\nparseOrThrow(\"{}\")" (Calls [ "parseOrThrow" ]) );
    ( "local runtime open",
      check "let parse = () => {open JSON; parseOrThrow(\"{}\")}"
        (Calls [ "parseOrThrow" ]) );
    ( "value alias keeps runtime contract without duplicate findings",
      check "let parse = JSON.parseOrThrow\nparse(\"{}\")" (Calls [ "parse" ])
    );
    ( "parameter shadows opened runtime contract",
      check "open JSON\nlet parse = parseOrThrow => parseOrThrow(\"{}\")" Clean
    );
    ( "module shadows runtime contract",
      check
        "module JSON = {let parseOrThrow = x => x}\nJSON.parseOrThrow(\"{}\")"
        Clean );
    ( "runtime spelling does not imply annotations",
      check "Option.getOrThrow(Some(1))" Clean );
    ( "ordinary JSON export is not annotated",
      check "JSON.stringify(JSON.Encode.string(\"value\"))" Clean );
    ( "legacy JSON spelling is not an annotated alias",
      check "Js.Json.parseExn(\"{}\")" Clean );
  ]

let handler_checks =
  [
    ( "catchall handles runtime contract",
      check "try JSON.parseOrThrow(\"{}\") catch {| _ => JSON.Null}" Clean );
    ( "variable handler handles runtime contract",
      check "try JSON.parseOrThrow(\"{}\") catch {| error => JSON.Null}" Clean
    );
    ( "named handler insufficient for any exception contract",
      check "try JSON.parseOrThrow(\"{}\") catch {| JsExn(_) => JSON.Null}"
        (Calls [ "JSON.parseOrThrow" ]) );
    ( "switch catchall handles runtime contract",
      check
        "switch JSON.parseOrThrow(\"{}\") {| value => value | exception _ => \
         JSON.Null}"
        Clean );
    ( "guarded catchall remains insufficient",
      check "try JSON.parseOrThrow(\"{}\") catch {| _ if flag => JSON.Null}"
        (Calls [ "JSON.parseOrThrow" ]) );
    ( "handled alias retains contract without duplicate errors",
      check
        "let parse = JSON.parseOrThrow\n\
         try parse(\"{}\") catch {| _ => JSON.Null}"
        Clean );
    ( "outer handler does not cover deferred callback",
      check
        "try (() => JSON.parseOrThrow(\"{}\")) catch {| _ => () => JSON.Null}"
        (Calls [ "JSON.parseOrThrow" ]) );
    ( "nested runtime calls report each callee once",
      check "JSON.stringifyAny(JSON.parseOrThrow(\"{}\"))"
        (Calls [ "JSON.stringifyAny"; "JSON.parseOrThrow" ]) );
  ]

let boundary_checks =
  [
    ( "default remains source local",
      check ~adapter:false "JSON.parseOrThrow(\"{}\")" Clean );
    ( "disabled throws rule bypasses selected runtime analysis",
      check ~enabled:false "Unknown.read()" Clean );
    ( "disabled throws rule bypasses invalid local metadata",
      check ~enabled:false "@throws(42)\nlet read = () => 0" Clean );
    ( "explicit adapter activates unknown qualified calls",
      check "Unknown.read()" (Analysis 1) );
    ( "unknown member does not become a plain function",
      check "JSON.notPublic(\"{}\")" (Analysis 1) );
    ( "private runtime helper remains hidden",
      check "JSON.Classify._internalClass(1)" (Analysis 1) );
    ( "unknown open fails explicitly",
      check "open Unknown\nlet value = 1" (Analysis 1) );
    ( "opaque runtime module open fails explicitly",
      check "open Belt.Id.MakeComparable\nlet value = 1" (Analysis 1) );
    ( "annotated callback escape fails explicitly",
      check "Array.map(values, JSON.parseOrThrow)" (Analysis 1) );
    ( "annotated partial application fails explicitly",
      check "JSON.parseOrThrow(\"{}\", ...)" (Analysis 1) );
    ( "await remains an explicit unsupported boundary",
      check "let parse = async () => await JSON.parseOrThrow(\"{}\")"
        (Analysis 1) );
    ( "annotation payload remains opaque",
      check "@@example(JSON.parseOrThrow(\"{}\"))\nlet value = 1" Clean );
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
    let root = Filename.temp_file "runtime-throws-" "" in
    Sys.remove root;
    Unix.mkdir root 0o700;
    Fun.protect ~finally:(fun () -> remove root) (fun () -> run root)
  with
  | Sys_error message -> Error ("Fixture I/O failed: " ^ message)
  | Unix.Unix_error (error, operation, path) ->
      Error (operation ^ " " ^ path ^ ": " ^ Unix.error_message error)

let project_check ?adapter files text expected =
  temporary (fun root ->
      Unix.mkdir (Filename.concat root "src") 0o700;
      write (Filename.concat root "rescript.json") "{\"sources\":\"src\"}";
      List.iter
        (fun (name, contents) ->
          write (Filename.concat root ("src/" ^ name)) contents)
        files;
      check_source ~root ?adapter
        Source.
          {
            filename = Filename.concat root "src/Main.res";
            text;
            kind = Implementation;
          }
        expected)

let project_checks =
  [
    ( "project root shadows only short JSON runtime path",
      project_check
        [ ("JSON.res", "let parseOrThrow = x => x") ]
        "JSON.parseOrThrow(\"{}\")\nStdlib.JSON.parseOrThrow(\"{}\")"
        (Calls [ "Stdlib.JSON.parseOrThrow" ]) );
    ( "project alias inherits seeded runtime contract",
      project_check
        [ ("Api.res", "let parse = JSON.parseOrThrow") ]
        "Api.parse(\"{}\")" (Calls [ "Api.parse" ]) );
    ( "project alias catchall handles seeded runtime contract",
      project_check
        [ ("Api.res", "let parse = JSON.parseOrThrow") ]
        "try Api.parse(\"{}\") catch {| _ => JSON.Null}" Clean );
    ( "project include inherits seeded runtime contract",
      project_check
        [ ("Api.res", "include JSON") ]
        "Api.parseOrThrow(\"{}\")" (Calls [ "Api.parseOrThrow" ]) );
    ( "project interface remains authoritative",
      project_check
        [
          ("Api.res", "let parse = JSON.parseOrThrow");
          ("Api.resi", "let parse: string => JSON.t");
        ]
        "Api.parse(\"{}\")" Clean );
    ( "default project analysis still ignores unannotated runtime refs",
      project_check ~adapter:false
        [ ("Api.res", "let parse = JSON.parseOrThrow") ]
        "Api.parse(\"{}\")" Clean );
    ( "runtime contract escape in provider does not become plain",
      project_check
        [ ("Api.res", "let pair = (JSON.parseOrThrow, 0)") ]
        "let (parse, _) = Api.pair\nparse(\"{}\")" (Analysis 1) );
    ( "project public interface hides private runtime alias",
      project_check
        [
          ("Api.res", "let parse = JSON.parseOrThrow\nlet value = 1");
          ("Api.resi", "let value: int");
        ]
        "Api.parse(\"{}\")" (Analysis 1) );
  ]

let () =
  let failures =
    inventory_checks @ resolution_checks @ handler_checks @ boundary_checks
    @ project_checks
    |> List.filter_map (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
