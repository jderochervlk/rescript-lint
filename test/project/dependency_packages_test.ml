open Rescript_linter
open Dependency_package_test_support

let fixture ?namespace ?dependencies directory =
  ( directory,
    manifest ?namespace ?dependencies directory,
    [ ("src/Api.res", "let read = () => 0") ] )

let discovery_checks =
  [
    ( "discovery does not parse sources",
      temporary
        [ ("pkg", manifest "pkg", [ ("src/Bad.res", "let =") ]) ]
        (fun _ roots ->
          match
            ( Dependency_packages.discover_files ~context:Throws_dependencies
                ~roots,
              Dependency_packages.load ~context:Throws_dependencies ~roots )
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
            ( Dependency_packages.discover_files ~context:Throws_dependencies
                ~roots,
              Dependency_packages.load ~context:Throws_dependencies ~roots )
          with
          | Ok discovered, Ok packages
            when discovered = Dependency_packages.files packages
                 && List.length discovered = 2 ->
              Ok ()
          | _ -> Error "Input file list mismatch") );
    ( "duplicate canonical roots rejected",
      temporary
        [ fixture "pkg" ]
        (fun _ roots ->
          match
            Dependency_packages.load ~context:Throws_dependencies
              ~roots:(roots @ roots)
          with
          | Error (Lint_error.Read_error _) -> Ok ()
          | _ -> Error "Duplicate roots accepted") );
    ( "malformed package JSON rejected",
      temporary
        [ fixture "pkg" ]
        (fun _ roots ->
          List.iter
            (fun root -> write (Filename.concat root "rescript.json") "{")
            roots;
          match
            Dependency_packages.load ~context:Throws_dependencies ~roots
          with
          | Error (Lint_error.Read_error _) -> Ok ()
          | _ -> Error "Malformed JSON accepted") );
    ( "missing explicit root rejected",
      temporary [] (fun root _ ->
          match
            Dependency_packages.load ~context:Throws_dependencies
              ~roots:[ Filename.concat root "missing" ]
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
          match
            Dependency_packages.load ~context:Throws_dependencies ~roots
          with
          | Error (Lint_error.Read_error _) -> Ok ()
          | _ -> Error "Source symlink followed") );
  ]

let duplicate_option expected = function
  | Error (Lint_error.Read_error { filename; detail })
    when filename = expected
         && detail = "Duplicate dependency package names or canonical roots." ->
      Ok ()
  | _ -> Error "Duplicate dependency diagnostic names the wrong option"

let missing_option expected = function
  | Error (Lint_error.Read_error { detail; _ })
    when detail
         = "Dependency absent requires an explicit " ^ expected ^ " root." ->
      Ok ()
  | _ -> Error "Missing dependency diagnostic names the wrong option"

let option_context_checks =
  [
    ( "source-root duplicate loading diagnostic",
      temporary
        [ fixture "pkg" ]
        (fun _ roots ->
          duplicate_option "sourceRootDependencies"
            (Dependency_packages.load ~context:Source_root_dependencies
               ~roots:(roots @ roots))) );
    ( "source-root duplicate discovery diagnostic",
      temporary
        [ fixture "pkg" ]
        (fun _ roots ->
          duplicate_option "sourceRootDependencies"
            (Dependency_packages.discover_files
               ~context:Source_root_dependencies ~roots:(roots @ roots))) );
    ( "source-root missing loading diagnostic",
      temporary
        [ fixture ~dependencies:[ "absent" ] "pkg" ]
        (fun _ roots ->
          missing_option "sourceRootDependencies"
            (Dependency_packages.load ~context:Source_root_dependencies ~roots))
    );
    ( "source-root missing discovery diagnostic",
      temporary
        [ fixture ~dependencies:[ "absent" ] "pkg" ]
        (fun _ roots ->
          missing_option "sourceRootDependencies"
            (Dependency_packages.discover_files
               ~context:Source_root_dependencies ~roots)) );
    ( "default throws duplicate diagnostic remains unchanged",
      temporary
        [ fixture "pkg" ]
        (fun _ roots ->
          duplicate_option "throwsDependencies"
            (Dependency_packages.load ~context:Throws_dependencies
               ~roots:(roots @ roots))) );
    ( "default throws missing diagnostic remains unchanged",
      temporary
        [ fixture ~dependencies:[ "absent" ] "pkg" ]
        (fun _ roots ->
          missing_option "throwsDependencies"
            (Dependency_packages.load ~context:Throws_dependencies ~roots)) );
  ]

let validation_checks =
  [
    ( "loading does not interpret exception annotations",
      temporary
        [
          ( "pkg",
            manifest "pkg",
            [ ("src/Api.res", "@throws(42) let read = () => 0") ] );
        ]
        (fun _ roots ->
          match
            Dependency_packages.load ~context:Source_root_dependencies ~roots
          with
          | Error error -> Error (Lint_error.render error)
          | Ok loaded -> (
              match Dependency_packages.validate ~project_modules:[] loaded with
              | Ok [ package ] when package.name = "pkg" -> Ok ()
              | _ -> Error "Shared loading interpreted exception annotations"))
    );
    ( "validation preserves parsed package order and metadata",
      temporary
        [
          fixture ~namespace:(`Bool true) ~dependencies:[ "a" ] "b";
          fixture ~namespace:(`Bool true) "a";
        ]
        (fun root roots ->
          match
            Dependency_packages.load ~context:Source_root_dependencies ~roots
          with
          | Error error -> Error (Lint_error.render error)
          | Ok loaded -> (
              match Dependency_packages.validate ~project_modules:[] loaded with
              | Ok [ b; a ]
                when b.name = "b" && a.name = "a" && b.namespace = Some "B"
                     && a.namespace = Some "A" && b.dependencies = [ "a" ]
                     && a.dependencies = []
                     && b.project.root = Filename.concat root "b"
                     && List.map
                          (fun unit -> unit.Project_files.name)
                          b.project.units
                        = [ "Api" ] ->
                  Ok ()
              | _ -> Error "Parsed package metadata or order changed")) );
    ( "public module collisions retain their diagnostic",
      temporary
        [ fixture "pkg" ]
        (fun root roots ->
          match
            Dependency_packages.load ~context:Source_root_dependencies ~roots
          with
          | Error error -> Error (Lint_error.render error)
          | Ok loaded -> (
              match
                Dependency_packages.validate ~project_modules:[ "Api" ] loaded
              with
              | Error (Lint_error.Read_error { filename; detail })
                when filename = Filename.concat root "pkg"
                     && detail = "Ambiguous public dependency module root Api."
                ->
                  Ok ()
              | _ -> Error "Public module collision diagnostic changed")) );
    ( "declaration cycles retain their diagnostic",
      temporary
        [
          fixture ~namespace:(`Bool true) ~dependencies:[ "b" ] "a";
          fixture ~namespace:(`Bool true) ~dependencies:[ "a" ] "b";
        ]
        (fun root roots ->
          match
            Dependency_packages.load ~context:Source_root_dependencies ~roots
          with
          | Error error -> Error (Lint_error.render error)
          | Ok loaded -> (
              match Dependency_packages.validate ~project_modules:[] loaded with
              | Error (Lint_error.Read_error { filename; detail })
                when filename = Filename.concat root "a/rescript.json"
                     && detail = "Cyclic dependency declarations: a -> b -> a"
                ->
                  Ok ()
              | _ -> Error "Declaration-cycle diagnostic changed")) );
  ]

let () =
  let failures =
    discovery_checks @ option_context_checks @ validation_checks
    |> List.filter_map (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
