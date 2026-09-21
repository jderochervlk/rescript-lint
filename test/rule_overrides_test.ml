open Rescript_linter

let settings pairs =
  `Assoc (List.map (fun (id, enabled) -> (id, `Bool enabled)) pairs)

let entry paths pairs =
  `Assoc
    [
      ("paths", `List (List.map (fun path -> `String path) paths));
      ("rules", settings pairs);
    ]

let configure ?(base = "/repo") ?(config = Rule_config.default) entries =
  Config_file.decode ~base config (`Assoc [ ("overrides", `List entries) ])

let success value = if value then Ok () else Error "Unexpected result."

let invalid = function
  | Error _ -> Ok ()
  | Ok _ -> Error "Invalid override accepted."

let state config filename id expected =
  Result.bind config (fun config ->
      success
        (Rule_config.enabled (Rule_config.for_file ~filename config) id
        = expected))

let generated =
  configure [ entry [ "src/generated" ] [ ("no-console", false) ] ]

let lint config filename text expected =
  Result.bind config (fun config ->
      let source = Source.{ filename; text; kind = Implementation } in
      Result.bind
        (Linter.lint_source_with_rules config source
        |> Result.map_error Lint_error.render)
        (fun diagnostics ->
          success
            (List.map
               (fun (diagnostic : Diagnostic.t) -> diagnostic.rule)
               diagnostics
            = expected)))

let invalid_entry value = invalid (configure [ value ])

let decode value =
  Config_file.decode ~base:"/repo" Rule_config.default
    (`Assoc [ ("overrides", value) ])

let checks =
  [
    ( "descendant match",
      state generated "/repo/src/generated/Model.res" "no-console" false );
    ("exact match", state generated "/repo/src/generated" "no-console" false);
    ( "sibling prefix not matched",
      state generated "/repo/src/generated-old/Model.res" "no-console" true );
    ( "other directory unaffected",
      state generated "/repo/src/Main.res" "no-console" true );
    ( "case sensitive paths",
      state generated "/repo/src/Generated/Model.res" "no-console" true );
    ( "dot and repeated separators normalized",
      state
        (configure [ entry [ "./src//generated/" ] [ ("no-console", false) ] ])
        "/repo/src/generated/Model.res" "no-console" false );
    ( "source dots normalized",
      state generated "/repo/src/other/../generated/./Model.res" "no-console"
        false );
    ( "source parent stays rooted",
      state
        (configure [ entry [ "/generated" ] [ ("no-console", false) ] ])
        "/../../generated/Model.res" "no-console" false );
    ( "absolute selector",
      state
        (configure
           [ entry [ "/outside/Generated.res" ] [ ("no-console", false) ] ])
        "/outside/Generated.res" "no-console" false );
    ( "file selector sibling unaffected",
      state
        (configure [ entry [ "src/Main.res" ] [ ("no-console", false) ] ])
        "/repo/src/Main.resi" "no-console" true );
    ( "multiple selectors union",
      state
        (configure [ entry [ "first"; "second" ] [ ("no-console", false) ] ])
        "/repo/second/Main.res" "no-console" false );
    ( "root selector explicit",
      state
        (configure [ entry [ "/" ] [ ("no-console", false) ] ])
        "/any/Main.res" "no-console" false );
    ( "dot selector is config directory",
      state
        (configure [ entry [ "." ] [ ("no-console", false) ] ])
        "/repo/Main.res" "no-console" false );
    ( "last matching setting wins",
      state
        (configure
           [
             entry [ "src" ] [ ("no-console", false) ];
             entry [ "src/generated" ] [ ("no-console", true) ];
           ])
        "/repo/src/generated/Main.res" "no-console" true );
    ( "later nonmatch does not overwrite",
      state
        (configure
           [
             entry [ "src" ] [ ("no-console", false) ];
             entry [ "other" ] [ ("no-console", true) ];
           ])
        "/repo/src/Main.res" "no-console" false );
    ( "optional rule activation",
      state
        (configure [ entry [ "src" ] [ ("no-warning-comments", true) ] ])
        "/repo/src/Main.res" "no-warning-comments" true );
    ( "other default rule preserved",
      state generated "/repo/src/generated/Main.res" "no-unsafe" true );
    ( "other optional rule preserved",
      state generated "/repo/src/generated/Main.res" "no-empty-file" false );
    ( "base remains unmodified",
      Result.bind generated (fun config ->
          success (Rule_config.enabled config "no-console")) );
    ( "effective configuration can resolve another file",
      Result.bind generated (fun config ->
          let effective =
            Rule_config.for_file ~filename:"/repo/src/generated/A.res" config
          in
          success
            (Rule_config.enabled
               (Rule_config.for_file ~filename:"/repo/src/B.res" effective)
               "no-console")) );
    ( "effective configuration is idempotent",
      Result.bind generated (fun config ->
          let effective =
            Rule_config.for_file ~filename:"/repo/src/generated/A.res" config
          in
          success
            (effective
            = Rule_config.for_file ~filename:"/repo/src/generated/A.res"
                effective)) );
    ( "base changes precede overrides",
      Result.bind generated (fun config ->
          state
            (Rule_config.set config ~id:"no-console" ~enabled:true)
            "/repo/src/generated/A.res" "no-console" false) );
    ( "base change on effective config does not leak prior overrides",
      Result.bind generated (fun config ->
          let effective =
            Rule_config.for_file ~filename:"/repo/src/generated/A.res" config
          in
          state
            (Rule_config.set effective ~id:"no-debugger" ~enabled:false)
            "/repo/src/B.res" "no-console" true) );
    ( "empty override array clears",
      Result.bind generated (fun config ->
          state (configure ~config []) "/repo/src/generated/A.res" "no-console"
            true) );
    ( "new array replaces old overrides",
      Result.bind generated (fun config ->
          state
            (configure ~config [ entry [ "other" ] [ ("no-console", false) ] ])
            "/repo/src/generated/A.res" "no-console" true) );
    ( "omitted overrides preserve",
      Result.bind generated (fun config ->
          state
            (Config_file.decode ~base:"/elsewhere" config (`Assoc []))
            "/repo/src/generated/A.res" "no-console" false) );
    ( "project root does not anchor selectors",
      state
        (Config_file.decode ~base:"/config" Rule_config.default
           (`Assoc
              [
                ("root", `String "/project");
                ( "overrides",
                  `List [ entry [ "src" ] [ ("no-console", false) ] ] );
              ]))
        "/config/src/Main.res" "no-console" false );
    ( "project root sources do not match config selectors",
      state
        (Config_file.decode ~base:"/config" Rule_config.default
           (`Assoc
              [
                ( "overrides",
                  `List [ entry [ "src" ] [ ("no-console", false) ] ] );
                ("root", `String "/project");
              ]))
        "/project/src/Main.res" "no-console" true );
    ( "project options preserved",
      Result.bind generated (fun config ->
          let options =
            {
              Project_options.default with
              jsx_runtime = Some React_dom;
              restricted_modules = [ "Database" ];
            }
          in
          let config =
            Rule_config.with_options options config
            |> Rule_config.for_file ~filename:"/repo/src/generated/A.res"
          in
          success (Rule_config.options config = options)) );
    ( "relative source resolves at config working directory",
      state
        (configure ~base:"." [ entry [ "src" ] [ ("no-console", false) ] ])
        "src/Main.res" "no-console" false );
    ( "lexical matcher supports nonexistent overlays",
      state generated "/repo/src/generated/UnsavedDoesNotExist.res" "no-console"
        false );
    ("missing override array type", invalid (decode (`Assoc [])));
    ("null overrides invalid", invalid (decode `Null));
    ("entry must object", invalid_entry (`String "generated"));
    ("empty entry invalid", invalid_entry (`Assoc []));
    ( "paths missing invalid",
      invalid_entry (`Assoc [ ("rules", settings [ ("no-console", false) ]) ])
    );
    ( "rules missing invalid",
      invalid_entry (`Assoc [ ("paths", `List [ `String "src" ]) ]) );
    ("paths empty invalid", invalid_entry (entry [] [ ("no-console", false) ]));
    ("rules empty invalid", invalid_entry (entry [ "src" ] []));
    ( "paths must array",
      invalid_entry
        (`Assoc
           [
             ("paths", `String "src");
             ("rules", settings [ ("no-console", false) ]);
           ]) );
    ( "path must string",
      invalid_entry
        (`Assoc
           [
             ("paths", `List [ `Int 1 ]);
             ("rules", settings [ ("no-console", false) ]);
           ]) );
    ( "empty selector invalid",
      invalid_entry (entry [ "" ] [ ("no-console", false) ]) );
    ( "whitespace selector invalid",
      invalid_entry (entry [ " \t" ] [ ("no-console", false) ]) );
    ( "parent traversal invalid",
      invalid_entry (entry [ "src/../generated" ] [ ("no-console", false) ]) );
    ( "glob star invalid",
      invalid_entry (entry [ "src/*.res" ] [ ("no-console", false) ]) );
    ( "glob question invalid",
      invalid_entry (entry [ "src/?.res" ] [ ("no-console", false) ]) );
    ( "glob bracket invalid",
      invalid_entry (entry [ "src/[ab].res" ] [ ("no-console", false) ]) );
    ( "glob brace invalid",
      invalid_entry (entry [ "src/{a,b}.res" ] [ ("no-console", false) ]) );
    ( "negation invalid",
      invalid_entry (entry [ "!src" ] [ ("no-console", false) ]) );
    ( "backslash invalid",
      invalid_entry (entry [ "src\\Main.res" ] [ ("no-console", false) ]) );
    ( "NUL invalid",
      invalid_entry (entry [ "src\000Main.res" ] [ ("no-console", false) ]) );
    ( "normalized duplicate selectors invalid",
      invalid_entry (entry [ "src"; "./src/" ] [ ("no-console", false) ]) );
    ( "rule value must boolean",
      invalid_entry
        (`Assoc
           [
             ("paths", `List [ `String "src" ]);
             ("rules", `Assoc [ ("no-console", `String "off") ]);
           ]) );
    ( "rules must object",
      invalid_entry
        (`Assoc [ ("paths", `List [ `String "src" ]); ("rules", `List []) ]) );
    ( "unknown rule invalid",
      invalid_entry (entry [ "src" ] [ ("no-such-rule", false) ]) );
    ("wildcard rule invalid", invalid_entry (entry [ "src" ] [ ("*", false) ]));
    ( "duplicate rule key invalid",
      invalid_entry
        (entry [ "src" ] [ ("no-console", false); ("no-console", true) ]) );
    ( "unknown property invalid",
      invalid_entry
        (`Assoc
           [
             ("files", `List [ `String "src" ]);
             ("rules", settings [ ("no-console", false) ]);
           ]) );
    ( "duplicate entry key invalid",
      invalid_entry
        (`Assoc
           [
             ("paths", `List [ `String "src" ]);
             ("paths", `List [ `String "other" ]);
             ("rules", settings [ ("no-console", false) ]);
           ]) );
    ( "adapter overrides invalid",
      invalid_entry
        (`Assoc
           [
             ("paths", `List [ `String "src" ]);
             ("rules", settings [ ("no-console", false) ]);
             ("jsxRuntime", `String "react-dom");
           ]) );
    ( "linter honors matching file",
      lint generated "/repo/src/generated/A.res" "Console.log(1)" [] );
    ( "linter honors nonmatching file",
      lint generated "/repo/src/A.res" "Console.log(1)" [ "no-console" ] );
    ( "linter keeps other safety rules",
      lint generated "/repo/src/generated/A.res" "Console.log(1)\n%debugger"
        [ "no-debugger" ] );
    ( "linter enables optional rule",
      lint
        (configure [ entry [ "src" ] [ ("no-warning-comments", true) ] ])
        "/repo/src/A.res" "// TODO\nlet value = 1" [ "no-warning-comments" ] );
    ( "linter keeps known suppression IDs",
      lint generated "/repo/src/generated/A.res"
        "// rescript-lint-disable-next-line no-console -- generated call\n\
         Console.log(1)"
        [ "suppression" ] );
    ( "known disabled suppression is unused, not unknown",
      Result.bind generated (fun config ->
          let source =
            Source.
              {
                filename = "/repo/src/generated/A.res";
                text =
                  "// rescript-lint-disable-next-line no-console -- generated \
                   call\n\
                   Console.log(1)";
                kind = Implementation;
              }
          in
          match Linter.lint_source_with_rules config source with
          | Ok [ diagnostic ] ->
              success
                (diagnostic.message
               = "Unused suppression for no-console. Reason: generated call")
          | _ -> Error "Expected a known but unused suppression.") );
    ( "disabled adapter rule has no prerequisite error",
      Result.bind
        (Rule_config.set Rule_config.default ~id:"jsx-a11y/alt-text"
           ~enabled:true) (fun config ->
          lint
            (configure ~config
               [ entry [ "src" ] [ ("jsx-a11y/alt-text", false) ] ])
            "/repo/src/A.res" "let image = <img />" []) );
    ( "enabled adapter rule still requires adapter",
      Result.bind
        (configure [ entry [ "src" ] [ ("jsx-a11y/alt-text", true) ] ])
        (fun config ->
          let source =
            Source.
              {
                filename = "/repo/src/A.res";
                text = "let image = <img />";
                kind = Implementation;
              }
          in
          match Linter.lint_source_with_rules config source with
          | Error (Lint_error.Analysis_errors (diagnostic, _)) ->
              success (diagnostic.rule = "adapter-analysis")
          | _ -> Error "Expected adapter prerequisite failure.") );
    ( "override cannot suppress parse errors",
      Result.bind generated (fun config ->
          let source =
            Source.
              {
                filename = "/repo/src/generated/A.res";
                text = "let =";
                kind = Implementation;
              }
          in
          match Linter.lint_source_with_rules config source with
          | Error (Lint_error.Parse_errors _) -> Ok ()
          | _ -> Error "Expected parse failure.") );
    ( "UTF8 paths match literally",
      state
        (configure [ entry [ "src/\195\169" ] [ ("no-console", false) ] ])
        "/repo/src/\195\169/Main.res" "no-console" false );
  ]

let () =
  let failed =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error message -> Some (name ^ ": " ^ message))
      checks
  in
  List.iter prerr_endline failed;
  if failed <> [] then exit 1
