open Rescript_linter

type expected =
  | Clean
  | Calls of string list
  | Analysis of string
  | Analysis_at of string * string * int * int
  | Read_failure of string

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
    let root = Filename.temp_file "project-throws-" "" in
    Sys.remove root;
    Unix.mkdir root 0o700;
    Fun.protect ~finally:(fun () -> remove root) (fun () -> run root)
  with
  | Sys_error message -> Error ("Fixture I/O failed: " ^ message)
  | Unix.Unix_error (error, operation, path) ->
      Error (operation ^ " " ^ path ^ ": " ^ Unix.error_message error)

let config ~enabled root =
  let initial =
    Rule_config.with_options
      { Project_options.default with root = Some root }
      Rule_config.default
  in
  List.fold_left
    (fun result (rule : Rule_config.rule) ->
      Result.bind result (fun config ->
          Rule_config.set config ~id:rule.id
            ~enabled:(enabled && rule.id = "no-unhandled-throws")))
    (Ok initial) Rule_config.rules

let actual_calls (source : Source.t) findings =
  List.map
    (fun (finding : Diagnostic.t) ->
      let start = finding.range.start.byte_offset in
      let finish = finding.range.finish.byte_offset in
      if
        finding.filename = source.filename
        && finding.rule = "no-unhandled-throws"
        && finding.fixes = [] && start >= 0 && finish >= start
        && finish <= String.length source.text
      then String.sub source.text start (finish - start)
      else "<invalid finding: " ^ Diagnostic.render finding ^ ">")
    findings

let expect source expected result =
  match (expected, result) with
  | Clean, Ok [] -> Ok ()
  | Calls wanted, Ok findings when actual_calls source findings = wanted ->
      Ok ()
  | Analysis rule, Error (Lint_error.Analysis_errors (first, rest))
    when List.for_all
           (fun (item : Diagnostic.t) ->
             item.rule = rule && item.message <> "" && item.fixes = [])
           (first :: rest) ->
      Ok ()
  | ( Analysis_at (rule, filename, start, finish),
      Error (Lint_error.Analysis_errors (item, [])) )
    when item.rule = rule
         && item.filename
            = Filename.concat (Filename.dirname source.filename) filename
         && item.range.start.byte_offset = start
         && item.range.finish.byte_offset = finish
         && item.range.start.line = 1 && item.range.finish.line = 1
         && item.range.start.column = start + 1
         && item.range.finish.column = finish + 1
         && item.message <> "" && item.fixes = [] ->
      Ok ()
  | Read_failure name, Error (Lint_error.Read_error { filename; detail })
    when Filename.basename filename = name && detail <> "" ->
      Ok ()
  | _, Error error -> Error (Lint_error.render error)
  | _, Ok findings ->
      Error
        ("Unexpected findings: "
        ^ String.concat " | " (List.map Diagnostic.render findings))

let check ?(enabled = true) ?(filename = "Main.res")
    ?(project_json = "{\"sources\":[\"src\"]}") files text expected =
  temporary (fun root ->
      Unix.mkdir (Filename.concat root "src") 0o700;
      write (Filename.concat root "rescript.json") project_json;
      List.iter
        (fun (name, contents) ->
          write (Filename.concat root ("src/" ^ name)) contents)
        files;
      let source =
        Source.
          {
            filename = Filename.concat root ("src/" ^ filename);
            text;
            kind =
              (if Filename.check_suffix filename ".resi" then Interface
               else Implementation);
          }
      in
      Result.bind (config ~enabled root) (fun config ->
          expect source expected (Linter.lint_source_with_rules config source)))

let api =
  ("Api.res", "exception Missing\n\n@throws(Missing)\nlet read = () => 0\n")

let imported text expected = check [ api ] text expected
let handled text = imported text Clean
let unhandled text callee = imported text (Calls [ callee ])

let basic_checks =
  [
    ("imported call", unhandled "Api.read()" "Api.read");
    ("unannotated caller", unhandled "let caller = () => Api.read()" "Api.read");
    ( "annotated caller still needs handler",
      unhandled "@throws(Api.Missing)\nlet caller = () => Api.read()" "Api.read"
    );
    ("named handler", handled "try Api.read() catch {| Api.Missing => 0}");
    ("wildcard handler", handled "try Api.read() catch {| _ => 0}");
    ("variable handler", handled "try Api.read() catch {| error => 0}");
    ( "switch named handler",
      handled
        "switch Api.read() {| value => value | exception Api.Missing => 0}" );
    ( "switch wildcard handler",
      handled "switch Api.read() {| value => value | exception _ => 0}" );
    ( "wrong local identity",
      unhandled "exception Missing\ntry Api.read() catch {| Missing => 0}"
        "Api.read" );
    ( "guarded handler is incomplete",
      unhandled "try Api.read() catch {| Api.Missing if flag => 0}" "Api.read"
    );
    ( "handler does not cover callback creation",
      unhandled "try (() => Api.read()) catch {| Api.Missing => () => 0}"
        "Api.read" );
    ( "handler body remains checked",
      unhandled "try 0 catch {| _ => Api.read()}" "Api.read" );
    ( "two call sites",
      imported "let first = Api.read()\nlet second = Api.read()"
        (Calls [ "Api.read"; "Api.read" ]) );
    ("value alias", unhandled "let fetch = Api.read\nfetch()" "fetch");
    ( "value alias handler",
      handled "let fetch = Api.read\ntry fetch() catch {| Api.Missing => 0}" );
    ("module alias", unhandled "module Alias = Api\nAlias.read()" "Alias.read");
    ( "module alias preserves exception identity",
      handled "module Alias = Api\ntry Api.read() catch {| Alias.Missing => 0}"
    );
    ("open", unhandled "open Api\nread()" "read");
    ("include", unhandled "include Api\nread()" "read");
    ("opened handler", handled "open Api\ntry read() catch {| Missing => 0}");
    ( "included handler",
      handled "include Api\ntry read() catch {| Missing => 0}" );
    ( "exception alias",
      handled
        "exception Alias = Api.Missing\ntry Api.read() catch {| Alias => 0}" );
    ( "parameter shadows imported value",
      handled "open Api\nlet caller = read => read()" );
    ( "module shadow does not erase captured contract",
      unhandled
        "let fetch = Api.read\nmodule Api = {let read = () => 1}\nfetch()"
        "fetch" );
    ( "local module shadows project module",
      handled "module Api = {let read = () => 1}\nApi.read()" );
  ]

let interface_checks =
  let plain = ("Api.resi", "exception Missing\nlet read: unit => int\n") in
  let declared =
    ("Api.resi", "exception Missing\n@throws(Missing)\nlet read: unit => int\n")
  in
  [
    ( "interface annotation imported",
      check
        [ ("Api.res", "exception Missing\nlet read = () => 0"); declared ]
        "Api.read()" (Calls [ "Api.read" ]) );
    ( "interface removes implementation annotation",
      check [ api; plain ] "Api.read()" Clean );
    ( "same exported exception in implementation and interface",
      check [ api; declared ] "try Api.read() catch {| Api.Missing => 0}" Clean
    );
    ( "interface changes named contract",
      check
        [
          ( "Api.res",
            "exception Missing\n\
             exception Public\n\
             @throws(Missing)\n\
             let read = () => 0" );
          ( "Api.resi",
            "exception Public\n@throws(Public)\nlet read: unit => int" );
        ]
        "try Api.read() catch {| Api.Public => 0}" Clean );
    ( "private implementation value unavailable",
      check
        [
          ( "Api.res",
            "exception Missing\n\
             @throws(Missing)\n\
             let read = () => 0\n\
             let hidden = () => 1" );
          declared;
        ]
        "Api.hidden()" (Analysis "throws-analysis") );
    ( "interface-only dependency",
      check [ declared ] "Api.read()" (Calls [ "Api.read" ]) );
    ( "interface-only named exception",
      check [ declared ] "try Api.read() catch {| Api.Missing => 0}" Clean );
    ( "nested interface contract",
      check
        [
          ( "Api.resi",
            "module Nested: {exception Missing\n\
             @throws(Missing)\n\
             let read: unit => int}" );
        ]
        "Api.Nested.read()" (Calls [ "Api.Nested.read" ]) );
    ( "nested interface handler",
      check
        [
          ( "Api.resi",
            "module Nested: {exception Missing\n\
             @throws(Missing)\n\
             let read: unit => int}" );
        ]
        "try Api.Nested.read() catch {| Api.Nested.Missing => 0}" Clean );
  ]

let dependency_checks =
  let same_offset = "exception Missing\n@throws(Missing)\nlet read = () => 0" in
  let distinct = [ ("First.res", same_offset); ("Second.res", same_offset) ] in
  let reexport contents = [ api; ("Bridge.res", contents) ] in
  [
    ( "different files have different exception identities",
      check distinct "try First.read() catch {| Second.Missing => 0}"
        (Calls [ "First.read" ]) );
    ( "each file's own exception matches",
      check distinct "try First.read() catch {| First.Missing => 0}" Clean );
    ( "cross-file value alias",
      check
        (reexport "let fetch = Api.read")
        "Bridge.fetch()" (Calls [ "Bridge.fetch" ]) );
    ( "cross-file module alias",
      check
        (reexport "module Alias = Api")
        "Bridge.Alias.read()" (Calls [ "Bridge.Alias.read" ]) );
    ( "cross-file include exports contract",
      check (reexport "include Api") "Bridge.read()" (Calls [ "Bridge.read" ])
    );
    ( "cross-file open and alias",
      check
        (reexport "open Api\nlet fetch = read")
        "Bridge.fetch()" (Calls [ "Bridge.fetch" ]) );
    ( "cross-file alias preserves exception identity",
      check (reexport "include Api")
        "try Bridge.read() catch {| Bridge.Missing => 0}" Clean );
    ( "annotation refers to imported exception",
      check
        [
          ("Errors.res", "exception Missing");
          ("Api.res", "@throws(Errors.Missing)\nlet read = () => 0");
        ]
        "try Api.read() catch {| Errors.Missing => 0}" Clean );
    ( "nested implementation contract",
      check
        [
          ( "Api.res",
            "module Nested = {exception Missing\n\
             @throws(Missing)\n\
             let read = () => 0}" );
        ]
        "Api.Nested.read()" (Calls [ "Api.Nested.read" ]) );
    ( "nested implementation handler",
      check
        [
          ( "Api.res",
            "module Nested = {exception Missing\n\
             @throws(Missing)\n\
             let read = () => 0}" );
        ]
        "try Api.Nested.read() catch {| Api.Nested.Missing => 0}" Clean );
    ( "all imported exceptions need handling",
      check
        [
          ( "Api.res",
            "exception First\n\
             exception Second(int)\n\
             @throws([First, Second])\n\
             let read = () => 0" );
        ]
        "try Api.read() catch {| Api.First => 0}" (Calls [ "Api.read" ]) );
    ( "imported payload handler",
      check
        [
          ( "Api.res",
            "exception Missing(int)\n@throws(Missing)\nlet read = () => 0" );
        ]
        "try Api.read() catch {| Api.Missing(_) => 0}" Clean );
  ]

let boundary_checks =
  [
    ( "unrelated annotated module does not activate unknown calls",
      imported "Remote.read()" Clean );
    ( "unknown project module fails explicitly when active",
      imported "let value = Api.read()\nRemote.read()"
        (Analysis "throws-analysis") );
    ( "unknown imported exception fails explicitly",
      check
        [ ("Api.res", "@throws(Remote.Missing)\nlet read = () => 0") ]
        "Api.read()" (Analysis "throws-analysis") );
    ( "malformed imported annotation fails explicitly",
      check
        [ ("Api.res", "@throws(42)\nlet read = () => 0") ]
        "Api.read()"
        (Analysis_at ("throws-analysis", "Api.res", 8, 10)) );
    ( "async imported annotation fails explicitly",
      check
        [ ("Api.res", "@throws(Not_found)\nlet read = async () => 0") ]
        "Api.read()" (Analysis "throws-analysis") );
    ( "promise interface contract fails explicitly",
      check
        [ ("Api.resi", "@throws\nlet read: unit => promise<int>") ]
        "Api.read()" (Analysis "throws-analysis") );
    ( "disabled rule skips unsupported imported contract",
      check ~enabled:false
        [ ("Api.res", "@throws(42)\nlet read = () => 0") ]
        "Api.read()" Clean );
    ( "disabled rule skips unsupported local contract",
      check ~enabled:false [] "@throws(42)\nlet read = () => 0" Clean );
    ( "no annotations retains unknown-call behavior",
      check [ ("Api.res", "let read = () => 0") ] "Remote.read()" Clean );
    ( "no annotations retains unknown-open behavior",
      check [ ("Api.res", "let read = () => 0") ] "open Remote\nread()" Clean );
    ( "unsaved source call replaces saved contents",
      check
        [ api; ("Main.res", "let value = 0") ]
        "Api.read()" (Calls [ "Api.read" ]) );
    ( "unsaved source handler replaces saved call",
      check
        [ api; ("Main.res", "Api.read()") ]
        "try Api.read() catch {| Api.Missing => 0}" Clean );
    ( "unsaved valid source replaces saved parse failure",
      check
        [ api; ("Main.res", "let =") ]
        "try Api.read() catch {| Api.Missing => 0}" Clean );
    ( "unsaved source removes invalid metadata",
      check
        [ api; ("Main.res", "@throws(42)\nlet read = () => 0") ]
        "try Api.read() catch {| Api.Missing => 0}" Clean );
    ( "unsaved interface replaces invalid metadata",
      check ~filename:"Api.resi"
        [ api; ("Api.resi", "@throws(42)\nlet read: unit => int") ]
        "exception Missing\n@throws(Missing)\nlet read: unit => int" Clean );
    ( "missing configured source directory fails explicitly",
      check ~project_json:"{\"sources\":[\"missing\"]}" [ api ] "Api.read()"
        (Read_failure "missing") );
  ]

let identity_checks =
  let implementation =
    "exception Missing\n@throws(Missing)\nlet read = () => 0\n"
  in
  let interface =
    ("Api.resi", "exception Missing\n@throws(Missing)\nlet read: unit => int")
  in
  let aliases =
    [
      ( "Api.res",
        "exception E\n\
         exception Alias = E\n\
         @throws([E, Alias])\n\
         let read = () => 0" );
      ( "Api.resi",
        "exception E\n\
         exception Alias\n\
         @throws([E, Alias])\n\
         let read: unit => int" );
    ]
  in
  [
    ( "implementation local handler shares public interface identity",
      check ~filename:"Api.res"
        [ ("Api.res", implementation); interface ]
        (implementation ^ "let caller = () => try read() catch {| Missing => 0}")
        Clean );
    ( "implementation handler matches qualified interface call",
      check ~filename:"Api.res"
        [ ("Api.res", implementation); interface ]
        (implementation
       ^ "let caller = () => try Api.read() catch {| Missing => 0}")
        Clean );
    ( "interface names retain implementation exception alias identity",
      check aliases "try Api.read() catch {| Api.E => 0}" Clean );
    ( "interface alias handles both public contract names",
      check aliases "try Api.read() catch {| Api.Alias => 0}" Clean );
    ( "hidden older exception is not the exported shadow identity",
      let implementation =
        "exception E\n\
         @throws(E)\n\
         let hidden = () => 0\n\
         exception E\n\
         @throws(E)\n\
         let read = () => 0\n\
         let caller = () => try hidden() catch {| E => 0}"
      in
      check ~filename:"Api.res"
        [
          ("Api.res", implementation);
          ("Api.resi", "exception E\n@throws(E)\nlet read: unit => int");
        ]
        implementation (Calls [ "hidden" ]) );
    ( "local exception does not become provider's public exception",
      check
        [ ("Api.res", implementation); interface ]
        "let caller = () => {exception Missing; try Api.read() catch {| \
         Missing => 0}}"
        (Calls [ "Api.read" ]) );
  ]

let indexing_checks =
  [
    ( "provider async body is not analyzed while indexing",
      check
        [
          ( "Api.res",
            "@throws(Not_found)\n\
             let read = () => 0\n\
             let delayed = async () => await Unknown.read()" );
        ]
        "try Api.read() catch {| Not_found => 0}" Clean );
    ( "provider opaque call body is not analyzed while indexing",
      check
        [ ("Api.res", "@throws(Not_found)\nlet read = () => Unknown.read()") ]
        "Api.read()" (Calls [ "Api.read" ]) );
    ( "provider callback escape body is not analyzed while indexing",
      check
        [
          ( "Api.res",
            "@throws(Not_found)\n\
             let read = () => 0\n\
             let callback = () => consume(read)" );
        ]
        "Api.read()" (Calls [ "Api.read" ]) );
  ]

let interface_scope_checks =
  let opened =
    [
      ("Errors.res", "exception Missing");
      ("Api.resi", "open Errors\n@throws(Missing)\nlet read: unit => int");
    ]
  in
  let nested =
    [
      ( "Api.resi",
        "exception Missing\n\
         module Nested: {@throws(Missing)\n\
         let read: unit => int}" );
    ]
  in
  [
    ( "interface open resolves annotation exceptions",
      check opened "try Api.read() catch {| Errors.Missing => 0}" Clean );
    ( "interface open does not reexport ambient exceptions",
      check opened "try Api.read() catch {| Api.Missing => 0}"
        (Calls [ "Api.read" ]) );
    ( "interface include imports public contract",
      check
        [ api; ("Bridge.resi", "include module type of Api") ]
        "Bridge.read()" (Calls [ "Bridge.read" ]) );
    ( "interface include exports original exception identity",
      check
        [ api; ("Bridge.resi", "include module type of Api") ]
        "try Bridge.read() catch {| Bridge.Missing => 0}" Clean );
    ( "interface module alias imports public contract",
      check
        [ api; ("Bridge.resi", "module Alias = Api") ]
        "Bridge.Alias.read()" (Calls [ "Bridge.Alias.read" ]) );
    ( "interface module alias exports exception identity",
      check
        [ api; ("Bridge.resi", "module Alias = Api") ]
        "try Bridge.Alias.read() catch {| Api.Missing => 0}" Clean );
    ( "nested interface may resolve an enclosing exception",
      check nested "try Api.Nested.read() catch {| Api.Missing => 0}" Clean );
    ( "nested interface does not export its ambient exception",
      check nested "try Api.Nested.read() catch {| Api.Nested.Missing => 0}"
        (Calls [ "Api.Nested.read" ]) );
  ]

let convergence_checks =
  let reverse =
    [
      ("A.res", "module Alias = B");
      ("B.res", "module Alias = C");
      ("C.res", "module Alias = Z");
      ("Z.res", "exception Missing\n@throws(Missing)\nlet read = () => 0");
    ]
  in
  let cyclic =
    [
      ("A.res", "module Alias = B\n@throws(Not_found)\nlet read = () => 0");
      ("B.res", "module Alias = A");
    ]
  in
  [
    ( "reverse-order three-hop module aliases converge",
      check reverse "A.Alias.Alias.Alias.read()"
        (Calls [ "A.Alias.Alias.Alias.read" ]) );
    ( "reverse-order aliases preserve exception identity",
      check reverse "try A.Alias.Alias.Alias.read() catch {| Z.Missing => 0}"
        Clean );
    ( "cyclic module references terminate with resolved contract",
      check cyclic "B.Alias.read()" (Calls [ "B.Alias.read" ]) );
    ( "cyclic module references retain handler identity",
      check cyclic "try B.Alias.read() catch {| Not_found => 0}" Clean );
    ( "unreferenced malformed provider does not poison active caller",
      check
        [ api; ("Broken.res", "@throws(42)\nlet read = () => 0") ]
        "Api.read()" (Calls [ "Api.read" ]) );
    ( "unreferenced malformed provider does not activate plain caller",
      check
        [ ("Broken.res", "@throws(42)\nlet read = () => 0") ]
        "Remote.read()" Clean );
    ( "public interface hides malformed implementation metadata",
      check
        [
          ("Api.res", "@throws(42)\nlet read = () => 0");
          ("Api.resi", "@throws(Not_found)\nlet read: unit => int");
        ]
        "Api.read()" (Calls [ "Api.read" ]) );
    ( "standalone provider throws attribute is invalid",
      check
        [ ("Api.res", "@@throws(Not_found)\nlet read = () => 0") ]
        "Api.read()" (Analysis "throws-analysis") );
    ( "expression-level provider throws attribute is invalid",
      check
        [ ("Api.res", "let read = () => 0\n@throws(Not_found) read()") ]
        "Api.read()" (Analysis "throws-analysis") );
    ( "unresolved qualified provider alias is not a plain function",
      check
        [
          ( "Api.res",
            "@throws(Not_found)\nlet read = () => 0\nlet fetch = Remote.read" );
        ]
        "Api.fetch()" (Analysis "throws-analysis") );
  ]

let initializer_checks =
  [
    ( "provider tuple cannot erase a local annotated function",
      check
        [
          ( "Api.res",
            "@throws(Not_found)\nlet read = () => 0\nlet pair = (read, 0)" );
        ]
        "let (fetch, _) = Api.pair\nfetch()" (Analysis "throws-analysis") );
    ( "provider destructuring cannot erase imported annotated function",
      check
        [ api; ("Bridge.res", "let (fetch, _) = (Api.read, 0)") ]
        "Bridge.fetch()" (Analysis "throws-analysis") );
    ( "provider higher-order initializer cannot erase annotated function",
      check
        [
          ( "Api.res",
            "@throws(Not_found)\nlet read = () => 0\nlet wrapped = wrap(read)"
          );
        ]
        "Api.wrapped()" (Analysis "throws-analysis") );
    ( "provider record cannot erase imported annotated function",
      check
        [ api; ("Bridge.res", "let callbacks = {fetch: Api.read}") ]
        "let {fetch} = Bridge.callbacks\nfetch()" (Analysis "throws-analysis")
    );
    ( "simple provider alias retains contract without escape error",
      check
        [
          ("Api.res", "@throws(Not_found)\nlet read = () => 0\nlet fetch = read");
        ]
        "Api.fetch()" (Calls [ "Api.fetch" ]) );
    ( "provider initializer calls do not become caller findings",
      check
        [
          ( "Api.res",
            "@throws(Not_found)\n\
             let read = () => 0\n\
             let initialized = read()\n\
             let plain = () => initialized" );
        ]
        "Api.plain()" Clean );
    ( "provider nested callback bodies remain outside metadata analysis",
      check
        [
          ( "Api.res",
            "@throws(Not_found)\n\
             let read = () => 0\n\
             let callbacks = [() => read]" );
        ]
        "Api.callbacks" Clean );
  ]

let () =
  let failures =
    basic_checks @ interface_checks @ dependency_checks @ boundary_checks
    @ identity_checks @ indexing_checks @ interface_scope_checks
    @ convergence_checks @ initializer_checks
    |> List.filter_map (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
