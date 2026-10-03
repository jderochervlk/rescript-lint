open Rescript_linter

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
  let root = Filename.temp_file "dependency-edges-" "" in
  Sys.remove root;
  Unix.mkdir root 0o700;
  Fun.protect ~finally:(fun () -> remove root) (fun () -> run root)

let package root name dependencies =
  let directory = Filename.concat root name in
  Unix.mkdir directory 0o700;
  Unix.mkdir (Filename.concat directory "src") 0o700;
  Yojson.Basic.to_file
    (Filename.concat directory "rescript.json")
    (`Assoc
       [
         ("name", `String name);
         ("namespace", `String (String.uppercase_ascii name));
         ("sources", `List [ `String "src" ]);
         ( "dependencies",
           `List (List.map (fun name -> `String name) dependencies) );
       ]);
  directory

let configuration root roots =
  Rule_config.with_options
    {
      Project_options.default with
      root = Some root;
      source_root_dependencies = roots;
      forbidden_source_roots = [ Filename.concat root "b/src" ];
    }
    Rule_config.default
  |> fun config ->
  Rule_config.set config ~id:"forbidden-source-root-reference" ~enabled:true

let check ?interface dependencies provider consumer expect =
  temporary (fun root ->
      Unix.mkdir (Filename.concat root "src") 0o700;
      write (Filename.concat root "rescript.json") {|{"sources":["src"]}|};
      let a = package root "a" dependencies in
      let b = package root "b" [] in
      let c = package root "c" [ "b" ] in
      write (Filename.concat a "src/Bridge.res") provider;
      Option.iter (write (Filename.concat a "src/Bridge.resi")) interface;
      write (Filename.concat b "src/Api.res") "let value = 1\ntype t = int\n";
      write (Filename.concat c "src/Bridge.res") "let alias = B.Api.value\n";
      let filename = Filename.concat root "src/Main.res" in
      write filename consumer;
      match configuration root [ a; b; c ] with
      | Error _ -> false
      | Ok config ->
          expect
            (Linter.lint_source_with_rules config
               Source.{ filename; text = consumer; kind = Implementation }))

let forbidden = function
  | Ok diagnostics ->
      List.exists
        (fun (diagnostic : Diagnostic.t) ->
          diagnostic.rule = "forbidden-source-root-reference")
        diagnostics
  | Error _ -> false

let unavailable = function
  | Error (Lint_error.Analysis_errors (first, _)) ->
      first.rule = "source-root-analysis"
      && String.ends_with ~suffix:"without a declared dependency edge."
           first.message
  | Ok _ | Error _ -> false

let clean = function Ok [] -> true | Ok _ | Error _ -> false

let blocked_checks =
  List.map
    (fun (name, provider, consumer) ->
      (name, check [] provider consumer unavailable))
    [
      ( "undeclared value alias",
        "let alias = B.Api.value\n",
        "let x = A.Bridge.alias\n" );
      ( "undeclared module alias",
        "module Alias = B.Api\n",
        "let x = A.Bridge.Alias.value\n" );
      ( "undeclared type alias",
        "type alias = B.Api.t\n",
        "let x: A.Bridge.alias = 1\n" );
      ( "undeclared open-dependent alias",
        "open B\nmodule Alias = Api\n",
        "let x = A.Bridge.Alias.value\n" );
      ("undeclared include", "include B.Api\n", "let x = A.Bridge.value\n");
    ]

let allowed_checks =
  [
    ( "declared dependency alias",
      check [ "b" ] "let alias = B.Api.value\n" "let x = A.Bridge.alias\n"
        forbidden );
    ( "declared transitive dependency alias",
      check [ "c" ] "let alias = B.Api.value\n" "let x = A.Bridge.alias\n"
        forbidden );
    ( "declared transitive re-export chain",
      check [ "c" ] "let alias = C.Bridge.alias\n" "let x = A.Bridge.alias\n"
        forbidden );
    ( "local shadow of blocked namespace",
      check []
        "module B = {module Api = {let value = 2}}\nlet alias = B.Api.value\n"
        "let x = A.Bridge.alias\n" clean );
    ( "public interface hides implementation reference",
      check ~interface:"let alias: int\n" [] "let alias = B.Api.value\n"
        "let x = A.Bridge.alias\n" clean );
    ( "public interface retains blocked module alias",
      check ~interface:"module Alias = B.Api\n" [] "module Alias = B.Api\n"
        "let x = A.Bridge.Alias.value\n" unavailable );
  ]

let () =
  let failures =
    blocked_checks @ allowed_checks
    |> List.filter_map (fun (name, passed) ->
        if passed then None else Some name)
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
