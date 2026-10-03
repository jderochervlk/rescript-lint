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
  let root = Filename.temp_file "project-provenance-" "" in
  Sys.remove root;
  Unix.mkdir root 0o700;
  Fun.protect ~finally:(fun () -> remove root) (fun () -> run root)

let mkdir root path = Unix.mkdir (Filename.concat root path) 0o700
let file root path = Filename.concat root path

let enable options =
  Rule_config.set
    (Rule_config.with_options options Rule_config.default)
    ~id:"forbidden-source-root-reference" ~enabled:true

let lint options filename text =
  match enable options with
  | Error message ->
      failwith ("Cannot enable provenance fixture rule: " ^ message)
  | Ok config ->
      Linter.lint_source_with_rules config
        Source.{ filename; text; kind = Implementation }

let lint_with_config config filename text =
  Linter.lint_source_with_rules config
    Source.{ filename; text; kind = Implementation }

let findings = function
  | Ok diagnostics ->
      List.filter
        (fun (finding : Diagnostic.t) ->
          finding.rule = "forbidden-source-root-reference")
        diagnostics
  | Error _ -> []

let clean result =
  match result with Ok diagnostics -> diagnostics = [] | Error _ -> false

let found result = findings result <> []

let analysis result =
  match result with
  | Error (Lint_error.Analysis_errors (first, rest)) ->
      List.for_all
        (fun (finding : Diagnostic.t) -> finding.rule = "source-root-analysis")
        (first :: rest)
  | _ -> false

let setup root =
  List.iter (mkdir root)
    [ "src"; "src/internal"; "src/internal-old"; "src/public" ];
  write
    (file root "rescript.json")
    {|{"sources":[{"dir":"src","subdirs":true}]}|};
  write
    (file root "src/internal/Secret.res")
    "let value = 1\n\
     type secret = int\n\
     type variant = Only\n\
     module Nested = {let value = 2\n\
     type t = int}\n";
  write (file root "src/internal/Consumer.res") "let saved = 0\n";
  write (file root "src/internal-old/Other.res") "let value = 1\n";
  write (file root "src/Main.res") "let saved = 0\n";
  write (file root "src/internal/Paired.res") "let value = 1\nlet hidden = 2\n";
  write (file root "src/public/Paired.resi") "let value: int\n";
  write (file root "src/public/Reverse.res") "let value = 1\n";
  write (file root "src/internal/Reverse.resi") "let value: int\n";
  write
    (file root "src/public/Facade.res")
    "let alias = Secret.value\n\
     type alias = Secret.secret\n\
     module Reexport = {include Secret}\n";
  write
    (file root "src/internal/RuntimeFacade.res")
    "let alias = Array.length\nmodule Nested = {let alias = Array.length}\n";
  write
    (file root "src/public/OpaqueFacade.res")
    "module type Shape = {let value: int}\n\
     module Factory = (X: Shape) => X\n\
     module Made = Factory(Secret)\n\
     let alias = Made.value\n\
     module Nested = {let alias = Made.value}\n";
  write
    (file root "src/public/OpaqueBridge.res")
    "let alias = OpaqueFacade.alias\n";
  write
    (file root "src/public/OpenFacade.res")
    "open Secret\nmodule Reexport = Nested\n";
  write
    (file root "src/public/OpenIncluded.res")
    "open Secret\ninclude Nested\n";
  write
    (file root "src/public/OpenInterface.res")
    "open Secret\nmodule Reexport = Nested\n";
  write
    (file root "src/public/OpenInterface.resi")
    "open Secret\nmodule Reexport = Nested\n";
  write
    (file root "src/public/IncludedInterface.res")
    "open Secret\ninclude Nested\n";
  write
    (file root "src/public/IncludedInterface.resi")
    "open Secret\ninclude module type of Nested\n"

let options root roots =
  {
    Project_options.default with
    root = Some root;
    forbidden_source_roots = roots;
  }

let project_checks root =
  setup root;
  let main = file root "src/Main.res" in
  let inside = file root "src/internal/Consumer.res" in
  let internal = file root "src/internal" in
  let src = file root "src" in
  let configured = options root [ internal ] in
  let alias =
    lint configured main "module Alias = Secret\nlet x = Alias.value\n"
  in
  let opened = lint configured main "open Secret\nlet x = value\n" in
  let included =
    lint configured main
      "module Facade = {include Secret}\nlet x = Facade.value\n"
  in
  let deterministic =
    lint configured main "let one = Secret.value\nlet two: Secret.secret = 1\n"
  in
  let overridden =
    let invalid = options root [ file root "missing" ] in
    match enable invalid with
    | Error _ -> false
    | Ok config -> (
        match
          Rule_config.with_overrides ~base:root config
            (`List
               [
                 `Assoc
                   [
                     ("paths", `List [ `String "src/Main.res" ]);
                     ( "rules",
                       `Assoc
                         [ ("forbidden-source-root-reference", `Bool false) ] );
                   ];
               ])
        with
        | Error _ -> false
        | Ok config ->
            clean (lint_with_config config main "let x = Secret.value\n"))
  in
  [
    ("forbidden value", found (lint configured main "let x = Secret.value\n"));
    ("forbidden type", found (lint configured main "let x: Secret.secret = 1\n"));
    ("same root exempt", clean (lint configured inside "let x = Secret.value\n"));
    ("module alias preserves origin", found alias);
    ( "module references are outside the rule",
      clean (lint configured main "module Alias = Secret\n") );
    ( "constructor references are outside the rule",
      clean (lint configured main "let x = Secret.Only\n") );
    ( "record-field labels are outside the rule",
      clean
        (lint configured main
           "type local = {field: int}\nlet read = value => value.field\n") );
    ("open preserves origin", found opened);
    ("include re-export preserves origin", found included);
    ( "value alias preserves origin",
      found (lint configured main "let alias = Secret.value\nlet x = alias\n")
    );
    ( "project value alias preserves origin",
      found (lint configured main "let x = Facade.alias\n") );
    ( "exported runtime alias remains external",
      clean (lint configured main "let x = RuntimeFacade.alias\n") );
    ( "nested exported runtime alias remains external",
      clean (lint configured main "let x = RuntimeFacade.Nested.alias\n") );
    ( "exported opaque alias remains unavailable",
      analysis (lint configured main "let x = OpaqueFacade.alias\n") );
    ( "nested exported opaque alias remains unavailable",
      analysis (lint configured main "let x = OpaqueFacade.Nested.alias\n") );
    ( "chained opaque alias remains unavailable",
      analysis (lint configured main "let x = OpaqueBridge.alias\n") );
    ( "type alias owns its declaration",
      clean (lint configured main "let x: Facade.alias = 1\n") );
    ( "project re-export preserves origin",
      found (lint configured main "let x = Facade.Reexport.value\n") );
    ( "module alias through open preserves value origin",
      found (lint configured main "let x = OpenFacade.Reexport.value\n") );
    ( "module alias through open preserves type origin",
      found (lint configured main "let x: OpenFacade.Reexport.t = 1\n") );
    ( "include through open preserves value origin",
      found (lint configured main "let x = OpenIncluded.value\n") );
    ( "include through open preserves type origin",
      found (lint configured main "let x: OpenIncluded.t = 1\n") );
    ( "interface alias through open preserves value origin",
      found (lint configured main "let x = OpenInterface.Reexport.value\n") );
    ( "interface alias through open preserves type origin",
      found (lint configured main "let x: OpenInterface.Reexport.t = 1\n") );
    ( "interface include through open preserves value origin",
      found (lint configured main "let x = IncludedInterface.value\n") );
    ( "interface include through open preserves type origin",
      found (lint configured main "let x: IncludedInterface.t = 1\n") );
    ( "interface open does not export imported values",
      clean (lint configured main "let x = OpenInterface.value\n") );
    ( "interface open does not export imported modules",
      clean (lint configured main "let x = OpenInterface.Nested.value\n") );
    ( "local shadow is exempt",
      clean (lint configured main "open Secret\nlet value = 2\nlet x = value\n")
    );
    ( "nested value",
      found (lint configured main "let x = Secret.Nested.value\n") );
    ("nested type", found (lint configured main "let x: Secret.Nested.t = 1\n"));
    ( "sibling prefix does not match",
      clean (lint configured main "let x = Other.value\n") );
    ( "first overlapping root exempts consumer",
      clean
        (lint (options root [ src; internal ]) main "let x = Secret.value\n") );
    ( "first matching nested root controls",
      found
        (lint (options root [ internal; src ]) main "let x = Secret.value\n") );
    ( "interface origin overrides implementation",
      clean (lint configured main "let x = Paired.value\n") );
    ( "interface hides implementation declarations",
      clean (lint configured main "let x = Paired.hidden\n") );
    ( "interface origin can be forbidden",
      found (lint configured main "let x = Reverse.value\n") );
    ( "suppression",
      clean
        (lint configured main
           "// rescript-lint-disable-next-line forbidden-source-root-reference\n\
            let x = Secret.value\n") );
    ( "deterministic value then type",
      match deterministic with
      | Ok [ first; second ] ->
          first.range.start.byte_offset < second.range.start.byte_offset
          && first.fixes = [] && Option.is_some first.help
          && first.symbol
             = Some Diagnostic.{ kind = Value; path = "Secret.value" }
          && second.symbol
             = Some Diagnostic.{ kind = Type; path = "Secret.secret" }
          && String.sub "let one = Secret.value\nlet two: Secret.secret = 1\n"
               first.range.start.byte_offset
               (first.range.finish.byte_offset - first.range.start.byte_offset)
             = "Secret.value"
      | _ -> false );
    ( "unknown functor result is explicit",
      analysis
        (lint configured main
           "module type Shape = {let value: int}\n\
            module Factory = (X: Shape) => X\n\
            module Made = Factory(Secret)\n\
            let x = Made.value\n") );
    ( "missing root is explicit",
      analysis
        (lint
           (options root [ file root "missing" ])
           main "let x = Secret.value\n") );
    ( "non-directory root is explicit",
      analysis (lint (options root [ main ]) main "let x = Secret.value\n") );
    ( "duplicate canonical roots are explicit",
      analysis
        (lint
           (options root [ internal; internal ])
           main "let x = Secret.value\n") );
    ("per-file override bypasses inactive prerequisites", overridden);
  ]

let symlink_checks root =
  setup root;
  let link = file root "protected" in
  Unix.symlink (file root "src/internal") link;
  let configured = options root [ link ] in
  [
    ( "symlink root matches target",
      found
        (lint configured (file root "src/Main.res") "let x = Secret.value\n") );
    ( "symlink root same-target exemption",
      clean
        (lint configured
           (file root "src/internal/Consumer.res")
           "let x = Secret.value\n") );
  ]

let namespace_checks root =
  setup root;
  let main = file root "src/Main.res" in
  let configured = options root [ file root "src/internal" ] in
  write
    (file root "src/public/NamespacedFacade.res")
    "let alias = MyProject.Secret.value\n";
  write
    (file root "rescript.json")
    {|{"name":"my-project","namespace":true,"sources":[{"dir":"src","subdirs":true}]}|};
  let inferred =
    found (lint configured main "let x = MyProject.Secret.value\n")
  in
  let alias = found (lint configured main "let x = NamespacedFacade.alias\n") in
  let typ =
    found (lint configured main "let x: MyProject.Secret.secret = 1\n")
  in
  let same_root =
    clean
      (lint configured
         (file root "src/internal/Consumer.res")
         "let x = MyProject.Secret.value\n")
  in
  write
    (file root "rescript.json")
    {|{"namespace":"Explicit","sources":[{"dir":"src","subdirs":true}]}|};
  let explicit =
    found (lint configured main "let x = Explicit.Secret.value\n")
  in
  write
    (file root "rescript.json")
    {|{"namespace":42,"sources":[{"dir":"src","subdirs":true}]}|};
  let invalid = analysis (lint configured main "let x = Secret.value\n") in
  write
    (file root "rescript.json")
    {|{"namespace":true,"sources":[{"dir":"src","subdirs":true}]}|};
  let missing_name = analysis (lint configured main "let x = Secret.value\n") in
  write
    (file root "rescript.json")
    {|{"namespace":"Secret","sources":[{"dir":"src","subdirs":true}]}|};
  let collision = analysis (lint configured main "let x = Secret.value\n") in
  [
    ("derived namespace value", inferred);
    ("namespace value alias", alias);
    ("namespace type", typ);
    ("namespace same-root exemption", same_root);
    ("explicit namespace", explicit);
    ("invalid namespace", invalid);
    ("namespace true requires name", missing_name);
    ("namespace collision", collision);
  ]

let dependency_checks root =
  setup root;
  mkdir root "dependency";
  mkdir root "dependency/src";
  write
    (file root "dependency/rescript.json")
    {|{"name":"source-dependency","sources":[{"dir":"src","subdirs":true}]}|};
  write
    (file root "dependency/src/DepApi.res")
    "let value = 1\ntype item = int\n";
  mkdir root "named-dependency";
  mkdir root "named-dependency/src";
  write
    (file root "named-dependency/rescript.json")
    {|{"name":"named-dependency","namespace":"Vendor","dependencies":["source-dependency"],"sources":[{"dir":"src","subdirs":true}]}|};
  write
    (file root "named-dependency/src/NsApi.res")
    "let value = DepApi.value\n";
  write (file root "src/internal/Utils.res") "let value = 1\n";
  write (file root "named-dependency/src/Utils.res") "let value = 2\n";
  write
    (file root "named-dependency/src/LocalFacade.res")
    "let alias = Utils.value\n";
  mkdir root "named-dependency/src/internal";
  write
    (file root "named-dependency/src/internal/ZSecret.res")
    "let value = 1\ntype t = int\n";
  write
    (file root "named-dependency/src/AFacade.res")
    "module Alias = ZSecret\n";
  write
    (file root "named-dependency/src/BFacade.res")
    "module Alias = AFacade.Alias\n";
  write
    (file root "named-dependency/src/ZFacade.res")
    "module Alias = ZSecret\n";
  write
    (file root "src/public/DependencyFacade.res")
    "let alias = DepApi.value\n";
  write
    (file root "src/public/DependencyBridge.res")
    "let alias = DependencyFacade.alias\n";
  let configured =
    {
      (options root [ file root "dependency/src" ]) with
      source_root_dependencies =
        [ file root "dependency"; file root "named-dependency" ];
    }
  in
  let main = file root "src/Main.res" in
  let dependency_value =
    found (lint configured main "let x = DepApi.value\n")
  in
  let dependency_type =
    found (lint configured main "let x: DepApi.item = 1\n")
  in
  let namespaced_value =
    found (lint configured main "let x = Vendor.NsApi.value\n")
  in
  let project_alias =
    found (lint configured main "let x = DependencyFacade.alias\n")
  in
  let chained_project_alias =
    found (lint configured main "let x = DependencyBridge.alias\n")
  in
  let package_local_shadow =
    clean
      (lint
         {
           configured with
           forbidden_source_roots = [ file root "src/internal" ];
         }
         main "let x = Vendor.LocalFacade.alias\n")
  in
  let package_local_origin =
    found
      (lint
         {
           configured with
           forbidden_source_roots = [ file root "named-dependency/src" ];
         }
         main "let x = Vendor.LocalFacade.alias\n")
  in
  write (file root "named-dependency/src/Utils.resi") "let value: int\n";
  let package_interface_origin =
    clean
      (lint
         {
           configured with
           forbidden_source_roots = [ file root "src/internal" ];
         }
         main "let x = Vendor.LocalFacade.alias\n")
  in
  let namespaced_aliases =
    let restricted =
      {
        configured with
        forbidden_source_roots = [ file root "named-dependency/src/internal" ];
      }
    in
    List.map
      (fun (name, reference) -> (name, found (lint restricted main reference)))
      [
        ( "forward namespaced module alias",
          "let x = Vendor.AFacade.Alias.value\n" );
        ( "chained namespaced module alias",
          "let x = Vendor.BFacade.Alias.value\n" );
        ( "backward namespaced module alias",
          "let x = Vendor.ZFacade.Alias.value\n" );
        ("namespaced module alias type", "let x: Vendor.AFacade.Alias.t = 1\n");
      ]
  in
  let missing_dependency =
    analysis
      (lint
         {
           configured with
           source_root_dependencies = [ file root "missing-dependency" ];
         }
         main "let x = DepApi.value\n")
  in
  write
    (file root "dependency/rescript.json")
    {|{"name":"source-dependency","dependencies":["source-dependency"],"sources":["src"]}|};
  let cyclic_dependency =
    analysis
      (lint
         {
           configured with
           source_root_dependencies = [ file root "dependency" ];
         }
         main "let x = DepApi.value\n")
  in
  [
    ("dependency value", dependency_value);
    ("dependency type", dependency_type);
    ("namespaced dependency value", namespaced_value);
    ("project alias to dependency value", project_alias);
    ("chained project alias to dependency value", chained_project_alias);
    ( "package-local shadow does not inherit project origin",
      package_local_shadow );
    ("package-local shadow retains dependency origin", package_local_origin);
    ( "package-local interface does not inherit project origin",
      package_interface_origin );
    ("missing dependency metadata is explicit", missing_dependency);
    ("cyclic dependency metadata is explicit", cyclic_dependency);
  ]
  @ namespaced_aliases

let dependency_shadow_checks root =
  setup root;
  List.iter (mkdir root) [ "imported"; "imported/src"; "local"; "local/src" ];
  write
    (file root "imported/rescript.json")
    {|{"name":"imported","sources":["src"]}|};
  write (file root "imported/src/Utils.res") "let value = 1\n";
  write
    (file root "local/rescript.json")
    {|{"name":"local","namespace":"Vendor","dependencies":["imported"],"sources":["src"]}|};
  write (file root "local/src/Utils.res") "let value = 2\n";
  write (file root "local/src/Utils.resi") "let value: int\n";
  write (file root "local/src/Facade.res") "let alias = Utils.value\n";
  let configured =
    {
      (options root [ file root "imported/src" ]) with
      source_root_dependencies = [ file root "imported"; file root "local" ];
    }
  in
  let main = file root "src/Main.res" in
  [
    ( "local interface shadows imported origin",
      clean (lint configured main "let x = Vendor.Facade.alias\n") );
    ( "local interface retains own origin",
      found
        (lint
           {
             configured with
             forbidden_source_roots = [ file root "local/src" ];
           }
           main "let x = Vendor.Facade.alias\n") );
  ]

let run_fixture name checks =
  temporary (fun root ->
      List.map
        (fun (case, passed) -> (name ^ ": " ^ case, passed))
        (checks root))

let () =
  let checks =
    run_fixture "project" project_checks
    @ run_fixture "symlink" symlink_checks
    @ run_fixture "namespace" namespace_checks
    @ run_fixture "dependency" dependency_checks
    @ run_fixture "dependency shadows" dependency_shadow_checks
  in
  let failures =
    List.filter_map
      (fun (name, passed) -> if passed then None else Some name)
      checks
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
