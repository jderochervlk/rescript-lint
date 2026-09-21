open Rescript_linter

type fixture = string * Yojson.Basic.t * (string * string) list

type expected =
  | Clean
  | Calls of string list
  | Analysis
  | Adapter_failure
  | Read_failure

let manifest ?namespace ?(dependencies = []) ?(sources = `String "src") name =
  `Assoc
    ([
       ("name", `String name);
       ("sources", sources);
       ("dependencies", `List (List.map (fun name -> `String name) dependencies));
     ]
    @ Option.to_list (Option.map (fun value -> ("namespace", value)) namespace)
    )

let api = "exception Missing\n@throws(Missing)\nlet read = () => 0"

let fixture ?namespace ?dependencies directory =
  ( directory,
    manifest ?namespace ?dependencies directory,
    [ ("src/Api.res", api) ] )

let write filename text =
  Out_channel.with_open_bin filename (fun channel -> output_string channel text)

let rec mkdir path =
  if not (Sys.file_exists path) then (
    mkdir (Filename.dirname path);
    Unix.mkdir path 0o700)

let rec remove path =
  if (Unix.lstat path).st_kind = Unix.S_DIR then (
    Array.iter
      (fun name -> remove (Filename.concat path name))
      (Sys.readdir path);
    Unix.rmdir path)
  else Sys.remove path

let install root (directory, config, files) =
  let package = Filename.concat root directory in
  mkdir (Filename.concat package "src");
  Yojson.Basic.to_file (Filename.concat package "rescript.json") config;
  List.iter
    (fun (name, text) ->
      let filename = Filename.concat package name in
      mkdir (Filename.dirname filename);
      write filename text)
    files;
  package

let temporary fixtures run =
  try
    let root = Filename.temp_file "throws-packages-" "" in
    Sys.remove root;
    Unix.mkdir root 0o700;
    Fun.protect
      ~finally:(fun () -> remove root)
      (fun () ->
        let roots = List.map (install root) fixtures in
        run root roots)
  with
  | Sys_error detail -> Error detail
  | Unix.Unix_error (error, operation, path) ->
      Error (operation ^ " " ^ path ^ ": " ^ Unix.error_message error)

let expect (source : Source.t) expected result =
  match (expected, result) with
  | Clean, Ok [] -> Ok ()
  | Read_failure, Error (Lint_error.Read_error _) -> Ok ()
  | Adapter_failure, Error (Lint_error.Analysis_errors (first, []))
    when first.rule = "adapter-analysis" ->
      Ok ()
  | Analysis, Error (Lint_error.Analysis_errors (first, rest))
    when List.for_all
           (fun (item : Diagnostic.t) ->
             item.rule = "throws-analysis" && item.fixes = [])
           (first :: rest) ->
      Ok ()
  | Calls wanted, Ok findings ->
      let references =
        List.map
          (fun (item : Diagnostic.t) ->
            if
              item.rule = "no-unhandled-throws"
              && item.filename = source.filename
              && item.fixes = []
            then
              String.sub source.text item.range.start.byte_offset
                (item.range.finish.byte_offset - item.range.start.byte_offset)
            else "<invalid finding>")
          findings
      in
      if references = wanted then Ok ()
      else Error ("Wrong calls: " ^ String.concat ", " references)
  | _, Error error -> Error (Lint_error.render error)
  | _, Ok findings ->
      Error
        ("Unexpected findings: "
        ^ String.concat " | " (List.map Diagnostic.render findings))

let check ?(initial = Throws_scope.initial) ?(project_modules = []) fixtures
    text expected =
  temporary fixtures (fun root roots ->
      let source =
        Source.
          {
            filename = Filename.concat root "Main.res";
            kind = Implementation;
            text;
          }
      in
      let result =
        Result.bind (Throws_packages.load ~roots) (fun packages ->
            Result.bind
              (Throws_packages.scope ~initial ~project_modules packages)
              (fun scope ->
                Result.bind (Parser.parse source)
                  (No_unhandled_throws.check ~scope ~source)))
      in
      expect source expected result)

let simple_checks =
  [
    ( "flat package contract",
      check [ fixture "plain" ] "Api.read()" (Calls [ "Api.read" ]) );
    ( "flat package named handler",
      check
        [ fixture "plain" ]
        "try Api.read() catch {| Api.Missing => 0}" Clean );
    ( "boolean namespace",
      check
        [ fixture ~namespace:(`Bool true) "my-package" ]
        "MyPackage.Api.read()" (Calls [ "MyPackage.Api.read" ]) );
    ( "namespace hides flat roots",
      check [ fixture ~namespace:(`Bool true) "pkg" ] "Api.read()" Analysis );
    ( "custom namespace",
      check
        [ fixture ~namespace:(`String "my-tools") "pkg" ]
        "MyTools.Api.read()" (Calls [ "MyTools.Api.read" ]) );
    ( "scoped npm namespace",
      check
        [
          ( "pkg",
            manifest ~namespace:(`Bool true) "@scope/package-name",
            [ ("src/Api.res", api) ] );
        ]
        "ScopePackageName.Api.read()" (Calls [ "ScopePackageName.Api.read" ]) );
    ( "string true namespace",
      check
        [ fixture ~namespace:(`String "true") "pkg" ]
        "Pkg.Api.read()" (Calls [ "Pkg.Api.read" ]) );
    ( "explicit false namespace",
      check
        [ fixture ~namespace:(`Bool false) "pkg" ]
        "Api.read()" (Calls [ "Api.read" ]) );
    ( "module aliases and open",
      check
        [ fixture ~namespace:(`Bool true) "pkg" ]
        "module A = Pkg.Api\nopen A\nread()" (Calls [ "read" ]) );
    ( "include and catchall",
      check
        [ fixture ~namespace:(`Bool true) "pkg" ]
        "include Pkg.Api\ntry read() catch {| _ => 0}" Clean );
    ("empty explicit package list", check [] "let value = 1" Clean);
    ( "runtime coexists with package",
      check ~initial:Throws_runtime.scope
        [ fixture "plain" ]
        "JSON.parseOrThrow(\"{}\")" (Calls [ "JSON.parseOrThrow" ]) );
    ( "package shadows runtime root",
      check ~initial:Throws_runtime.scope
        [
          ( "pkg",
            manifest "pkg",
            [ ("src/JSON.res", "let parseOrThrow = x => x") ] );
        ]
        "JSON.parseOrThrow(\"{}\")" Clean );
  ]

let interface_checks =
  [
    ( "interface declaration contract",
      check
        [
          ( "pkg",
            manifest "pkg",
            [
              ("src/Api.res", "exception Missing\nlet read = () => 0");
              ( "src/Api.resi",
                "exception Missing\n@throws(Missing)\nlet read: unit => int" );
            ] );
        ]
        "Api.read()" (Calls [ "Api.read" ]) );
    ( "interface removes implementation contract",
      check
        [
          ( "pkg",
            manifest "pkg",
            [
              ("src/Api.res", api);
              ("src/Api.resi", "exception Missing\nlet read: unit => int");
            ] );
        ]
        "Api.read()" Clean );
    ( "interface hides implementation alias",
      check
        [
          ( "pkg",
            manifest "pkg",
            [
              ("src/Api.res", api ^ "\nlet privateRead = read");
              ( "src/Api.resi",
                "exception Missing\n@throws(Missing)\nlet read: unit => int" );
            ] );
        ]
        "Api.privateRead()" Analysis );
    ( "interface exception identity",
      check
        [
          ( "pkg",
            manifest "pkg",
            [
              ("src/Api.res", api);
              ( "src/Api.resi",
                "exception Missing\n@throws(Missing)\nlet read: unit => int" );
            ] );
        ]
        "try Api.read() catch {| Api.Missing => 0}" Clean );
    ( "unsupported public metadata",
      check
        [
          ( "pkg",
            manifest "pkg",
            [ ("src/Api.resi", "@throws(42)\nlet read: unit => int") ] );
        ]
        "let value = 1" Analysis );
    ( "hidden invalid metadata excluded",
      check
        [
          ( "pkg",
            manifest "pkg",
            [
              ("src/Api.res", "@throws(42)\nlet read = () => 0");
              ("src/Api.resi", "let read: unit => int");
            ] );
        ]
        "Api.read()" Clean );
    ( "provider body not analyzed",
      check
        [
          ( "pkg",
            manifest "pkg",
            [
              ( "src/Api.res",
                "@throws(Not_found)\nlet read = () => Remote.read()" );
            ] );
        ]
        "Api.read()" (Calls [ "Api.read" ]) );
    ( "provider export escape fails",
      check
        [
          ( "pkg",
            manifest "pkg",
            [ ("src/Api.res", api ^ "\nlet pair = (read, 0)") ] );
        ]
        "let value = 1" Analysis );
  ]

let graph_checks =
  let a = fixture ~namespace:(`Bool true) "a" in
  let b =
    ( "b",
      manifest ~namespace:(`Bool true) ~dependencies:[ "a" ] "b",
      [ ("src/Bridge.res", "let read = A.Api.read") ] )
  in
  let c =
    ( "c",
      manifest ~namespace:(`Bool true) ~dependencies:[ "b" ] "c",
      [ ("src/Bridge.res", "let read = B.Bridge.read") ] )
  in
  [
    ( "direct package dependency",
      check [ b; a ] "B.Bridge.read()" (Calls [ "B.Bridge.read" ]) );
    ( "transitive dependency order",
      check [ c; b; a ] "C.Bridge.read()" (Calls [ "C.Bridge.read" ]) );
    ( "transitive exception identity",
      check [ c; a; b ] "try C.Bridge.read() catch {| A.Api.Missing => 0}" Clean
    );
    ( "same filenames remain package-local",
      check
        [ a; fixture ~namespace:(`Bool true) "b" ]
        "try A.Api.read() catch {| B.Api.Missing => 0}" (Calls [ "A.Api.read" ])
    );
    ( "undeclared package cannot leak into provider",
      check
        [
          a;
          ( "b",
            manifest ~namespace:(`Bool true) "b",
            [ ("src/Bridge.res", "let read = A.Api.read") ] );
        ]
        "B.Bridge.read()" Analysis );
    ("missing required explicit root", check [ b ] "let value = 1" Read_failure);
    ( "cyclic package graph",
      check
        [
          fixture ~namespace:(`Bool true) ~dependencies:[ "b" ] "a";
          fixture ~namespace:(`Bool true) ~dependencies:[ "a" ] "b";
        ]
        "let value = 1" Read_failure );
    ( "duplicate flat exported modules",
      check [ fixture "a"; fixture "b" ] "let value = 1" Read_failure );
    ( "duplicate namespace roots",
      check
        [
          fixture ~namespace:(`String "Public") "a";
          fixture ~namespace:(`String "Public") "b";
        ]
        "let value = 1" Read_failure );
    ( "project package root collision",
      check ~project_modules:[ "Api" ]
        [ fixture "a" ]
        "let value = 1" Read_failure );
    ( "duplicate package identities",
      check
        [
          fixture "a";
          ("b", manifest "a", [ ("src/Other.res", "let value = 1") ]);
        ]
        "let value = 1" Read_failure );
  ]

let alias_checks =
  let base =
    ( "base",
      manifest ~namespace:(`Bool true) "base",
      [ ("src/Errors.res", "exception Missing") ] )
  in
  let reexport name =
    ( name,
      manifest ~namespace:(`Bool true) ~dependencies:[ "base" ] name,
      [
        ( "src/Api.res",
          "exception Missing = Base.Errors.Missing\n\
           @throws(Missing)\n\
           let read = () => 0" );
        ( "src/Api.resi",
          "exception Missing\n@throws(Missing)\nlet read: unit => int" );
      ] )
  in
  [
    ( "cross-package interface alias matches original",
      check
        [ reexport "a"; base ]
        "try A.Api.read() catch {| Base.Errors.Missing => 0}" Clean );
    ( "cross-package alias reverse input order",
      check
        [ base; reexport "a" ]
        "try A.Api.read() catch {| Base.Errors.Missing => 0}" Clean );
    ( "multiple interface aliases converge",
      check
        [ reexport "c"; base; reexport "a" ]
        "try C.Api.read() catch {| A.Api.Missing => 0}" Clean );
    ( "unrelated exception identities not unified",
      check
        [ base; reexport "a"; fixture ~namespace:(`Bool true) "other" ]
        "try A.Api.read() catch {| Other.Api.Missing => 0}"
        (Calls [ "A.Api.read" ]) );
  ]

let decode_good name json predicate =
  ( name,
    match Throws_package_config.decode json with
    | Ok config when predicate config -> Ok ()
    | Ok _ -> Error "Decoded package configuration mismatch"
    | Error detail -> Error detail )

let decode_bad name json =
  ( name,
    match Throws_package_config.decode json with
    | Error _ -> Ok ()
    | Ok _ -> Error "Invalid configuration accepted" )

let config_checks =
  let base fields =
    `Assoc (("name", `String "pkg") :: ("sources", `String "src") :: fields)
  in
  [
    decode_good "legacy dependency field"
      (base [ ("bs-dependencies", `List [ `String "dep" ]) ])
      (fun c -> c.dependencies = [ "dep" ]);
    decode_good "array source descriptions"
      (manifest
         ~sources:
           (`List
              [
                `String "src";
                `Assoc [ ("dir", `String "lib"); ("subdirs", `Bool true) ];
              ])
         "pkg")
      (fun c -> List.length c.directories = 2);
    decode_good "development sources excluded"
      (manifest
         ~sources:
           (`Assoc
              [
                ("dir", `String "test");
                ("type", `String "dev");
                ("subdirs", `Bool true);
              ])
         "pkg")
      (fun c -> c.directories = []);
    decode_good "uppercase custom namespace"
      (base [ ("namespace", `String "XML") ])
      (fun c -> c.namespace = Some "XML");
    decode_bad "config object required" (`List []);
    decode_bad "duplicate config property" (base [ ("name", `String "other") ]);
    decode_bad "package name required" (`Assoc [ ("sources", `String "src") ]);
    decode_bad "nonempty name required" (manifest "");
    decode_bad "sources required" (`Assoc [ ("name", `String "pkg") ]);
    decode_bad "dependency array required"
      (base [ ("dependencies", `String "dep") ]);
    decode_bad "dependency name required"
      (base [ ("dependencies", `List [ `Int 1 ]) ]);
    decode_bad "dependency key conflict"
      (base [ ("dependencies", `List []); ("bs-dependencies", `List []) ]);
    decode_bad "namespace type" (base [ ("namespace", `Int 1) ]);
    decode_bad "namespace entry unsupported"
      (base [ ("namespace-entry", `String "Index") ]);
    decode_bad "invalid normalized namespace"
      (base [ ("namespace", `String "123") ]);
    decode_bad "nonempty compiler flags unsupported"
      (base [ ("bsc-flags", `List [ `String "-open" ]) ]);
    decode_bad "invalid source kind" (manifest ~sources:(`Int 1) "pkg");
    decode_bad "empty source path" (manifest ~sources:(`String "") "pkg");
    decode_bad "nested source tree unsupported"
      (manifest
         ~sources:(`Assoc [ ("dir", `String "src"); ("subdirs", `List []) ])
         "pkg");
    decode_bad "unknown source field"
      (manifest
         ~sources:(`Assoc [ ("dir", `String "src"); ("files", `List []) ])
         "pkg");
    decode_bad "duplicate source field"
      (manifest
         ~sources:(`Assoc [ ("dir", `String "src"); ("dir", `String "other") ])
         "pkg");
  ]

let discovery_checks =
  [
    ( "development syntax errors are not loaded",
      check
        [
          ( "pkg",
            manifest
              ~sources:
                (`List
                   [
                     `String "src";
                     `Assoc
                       [ ("dir", `String "tests"); ("type", `String "dev") ];
                   ])
              "pkg",
            [ ("src/Api.res", api); ("tests/Bad.res", "let =") ] );
        ]
        "Api.read()" (Calls [ "Api.read" ]) );
    ( "recursive source scanning",
      check
        [
          ( "pkg",
            manifest
              ~sources:
                (`Assoc [ ("dir", `String "src"); ("subdirs", `Bool true) ])
              "pkg",
            [
              ("src/nested/Api.res", api);
              ("src/readme.txt", "ignored");
              ("src/node_modules/Ignored.res", "let =");
            ] );
        ]
        "Api.read()" (Calls [ "Api.read" ]) );
    ( "flat source ignores nested modules",
      check
        [ ("pkg", manifest "pkg", [ ("src/nested/Api.res", api) ]) ]
        "Api.read()" Analysis );
    ( "source escape rejected",
      check
        [ ("pkg", manifest ~sources:(`String "../") "pkg", []) ]
        "let value = 1" Read_failure );
    ( "missing source rejected",
      check
        [ ("pkg", manifest ~sources:(`String "missing") "pkg", []) ]
        "let value = 1" Read_failure );
    ( "ambiguous module names rejected",
      check
        [
          ( "pkg",
            manifest
              ~sources:
                (`Assoc [ ("dir", `String "src"); ("subdirs", `Bool true) ])
              "pkg",
            [ ("src/Api.res", api); ("src/nested/Api.res", api) ] );
        ]
        "let value = 1" Read_failure );
    ( "exotic module name rejected",
      check
        [ ("pkg", manifest "pkg", [ ("src/Api.test.res", api) ]) ]
        "let value = 1" Read_failure );
    ( "discovery does not parse sources",
      temporary
        [ ("pkg", manifest "pkg", [ ("src/Bad.res", "let =") ]) ]
        (fun _ roots ->
          match
            (Throws_packages.discover_files ~roots, Throws_packages.load ~roots)
          with
          | Ok files, Error (Lint_error.Parse_errors _)
            when List.length files = 2 ->
              Ok ()
          | _ -> Error "Discovery parsed sources or load ignored parse failure")
    );
    ( "input list includes config and source",
      temporary
        [ fixture "pkg" ]
        (fun _ roots ->
          match
            (Throws_packages.discover_files ~roots, Throws_packages.load ~roots)
          with
          | Ok discovered, Ok packages
            when discovered = Throws_packages.files packages
                 && List.length discovered = 2 ->
              Ok ()
          | _ -> Error "Input file list mismatch") );
    ( "duplicate canonical roots rejected",
      temporary
        [ fixture "pkg" ]
        (fun _ roots ->
          match Throws_packages.load ~roots:(roots @ roots) with
          | Error (Lint_error.Read_error _) -> Ok ()
          | _ -> Error "Duplicate roots accepted") );
    ( "malformed package JSON rejected",
      temporary
        [ fixture "pkg" ]
        (fun _ roots ->
          List.iter
            (fun root -> write (Filename.concat root "rescript.json") "{")
            roots;
          match Throws_packages.load ~roots with
          | Error (Lint_error.Read_error _) -> Ok ()
          | _ -> Error "Malformed JSON accepted") );
    ( "missing explicit root rejected",
      temporary [] (fun root _ ->
          match
            Throws_packages.load ~roots:[ Filename.concat root "missing" ]
          with
          | Error (Lint_error.Read_error _) -> Ok ()
          | _ -> Error "Missing package accepted") );
    ( "source symlink rejected",
      temporary
        [ fixture "pkg" ]
        (fun _ roots ->
          List.iter
            (fun root ->
              Unix.symlink "Api.res" (Filename.concat root "src/Link.res"))
            roots;
          match Throws_packages.load ~roots with
          | Error (Lint_error.Read_error _) -> Ok ()
          | _ -> Error "Source symlink followed") );
  ]

let public_check ?(enabled = true) ?(project = true) ?(runtime = false)
    ?(missing = false) ?(project_files = []) fixtures text expected =
  temporary fixtures (fun root roots ->
      let project_root = Filename.concat root "project" in
      mkdir (Filename.concat project_root "src");
      write
        (Filename.concat project_root "rescript.json")
        "{\"sources\":\"src\"}";
      List.iter
        (fun (name, text) ->
          write (Filename.concat project_root ("src/" ^ name)) text)
        project_files;
      let filename = Filename.concat project_root "src/Main.res" in
      write filename text;
      let options =
        {
          Project_options.default with
          root = (if project then Some project_root else None);
          throws_dependencies =
            (if missing then [ Filename.concat root "missing" ] else roots);
          throws_runtime = (if runtime then Some Rescript_12_3_1 else None);
        }
      in
      let config =
        List.fold_left
          (fun result (rule : Rule_config.rule) ->
            Result.bind result (fun config ->
                Rule_config.set config ~id:rule.id
                  ~enabled:(enabled && rule.id = "no-unhandled-throws")))
          (Ok (Rule_config.with_options options Rule_config.default))
          Rule_config.rules
      in
      let source = Source.{ filename; text; kind = Implementation } in
      Result.bind config (fun config ->
          expect source expected (Linter.lint_source_with_rules config source)))

let public_checks =
  [
    ( "configured dependencies activate caller",
      public_check [ fixture "pkg" ] "Api.read()" (Calls [ "Api.read" ]) );
    ( "configured dependency named handler",
      public_check
        [ fixture "pkg" ]
        "try Api.read() catch {| Api.Missing => 0}" Clean );
    ( "dependency configuration requires project",
      public_check ~project:false [ fixture "pkg" ] "Api.read()" Adapter_failure
    );
    ( "disabled rule bypasses dependency IO",
      public_check ~enabled:false ~missing:true [] "Remote.read()" Clean );
    ( "disabled rule bypasses project requirement",
      public_check ~enabled:false ~project:false
        [ fixture "pkg" ]
        "Api.read()" Clean );
    ( "missing configured dependency fails",
      public_check ~missing:true [] "let value = 1" Read_failure );
    ( "explicit package selection activates unknown calls",
      public_check [ fixture "pkg" ] "Remote.read()" Analysis );
    ( "runtime and configured dependencies coexist",
      public_check ~runtime:true
        [ fixture "pkg" ]
        "JSON.parseOrThrow(\"{}\")" (Calls [ "JSON.parseOrThrow" ]) );
    ( "project dependency module collision fails",
      public_check
        ~project_files:[ ("Api.res", "let read = () => 0") ]
        [ fixture "pkg" ]
        "Api.read()" Read_failure );
    ( "empty dependency selection retains source behavior",
      public_check [] "Remote.read()" Clean );
  ]

let () =
  let failures =
    simple_checks @ interface_checks @ graph_checks @ alias_checks
    @ config_checks @ discovery_checks @ public_checks
    |> List.filter_map (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
