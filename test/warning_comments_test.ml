open Rescript_linter

let configured ?(terms = Policy_rules.default_warning_terms)
    ?(allowed_contexts = []) () =
  Policy_rules.warning_policy ~terms ~allowed_contexts

let inspect ?(kind = Source.Implementation) policy text =
  let source = Source.{ filename = "warnings.res"; text; kind } in
  Result.bind policy (fun warning_policy ->
      Parser.parse_document source
      |> Result.map_error Lint_error.render
      |> Result.map (fun document ->
          Policy_rules.check ~warning_policy ~source document
          |> List.filter (fun (diagnostic : Diagnostic.t) ->
              diagnostic.rule = "no-warning-comments")))

let count ?kind policy expected text =
  match inspect ?kind policy text with
  | Ok diagnostics when List.length diagnostics = expected -> Ok ()
  | Ok diagnostics ->
      Error
        (Printf.sprintf "Expected %d warnings, got %d." expected
           (List.length diagnostics))
  | Error message -> Error message

let invalid policy =
  match policy with
  | Error _ -> Ok ()
  | Ok _ -> Error "Accepted invalid policy."

let success condition = if condition then Ok () else Error "Unexpected result."
let default = configured ()
let custom = configured ~terms:[ "review_me"; "BUG2" ] ()
let declaration = "\nlet value = 1"

let context_count allowed_contexts expected =
  count
    (configured ~allowed_contexts ())
    expected
    ("// TODO\n/* FIXME */\n/** HACK */" ^ declaration)

let synthetic_documentation standalone =
  let text = if standalone then "/*** TODO */" else "/** TODO */" in
  let source =
    Source.{ filename = "synthetic.res"; text; kind = Implementation }
  in
  let start =
    { Lexing.dummy_pos with pos_lnum = 1; pos_bol = 0; pos_cnum = 0 }
  in
  let loc =
    Location.
      {
        loc_start = start;
        loc_end = { start with pos_cnum = String.length text };
        loc_ghost = false;
      }
  in
  let comment =
    Res_comment.make_multi_line_comment ~loc ~doc_comment:true ~standalone
      " TODO "
  in
  let document = Parser.{ tree = Implementation []; comments = [ comment ] } in
  Result.bind (configured ~allowed_contexts:[ Documentation ] ())
    (fun warning_policy ->
      let warnings =
        Policy_rules.check ~warning_policy ~source document
        |> List.filter (fun (item : Diagnostic.t) ->
            item.rule = "no-warning-comments")
      in
      success (warnings = []))

let checks =
  [
    ("default terms", count default 1 ("// TODO FIXME HACK" ^ declaration));
    ( "case insensitive defaults",
      count default 1 ("// todo FiXmE hAcK" ^ declaration) );
    ("custom terms", count custom 1 ("// REVIEW_ME bug2" ^ declaration));
    ( "custom replaces defaults",
      count custom 0 ("// TODO FIXME HACK" ^ declaration) );
    ( "custom underscores are whole words",
      count custom 0 ("// XREVIEW_ME REVIEW_ME_X BUG20" ^ declaration) );
    ( "ASCII punctuation separates terms",
      count default 1 ("// [TODO]: (FIXME), HACK!" ^ declaration) );
    ( "ASCII numeric and underscore adjacency",
      count default 0 ("// 1TODO TODO1 _TODO TODO_ XTODO TODOX" ^ declaration)
    );
    ( "UTF8 suffix stays part of word",
      count default 0 ("// TODO\195\169" ^ declaration) );
    ( "UTF8 prefix stays part of word",
      count default 0 ("// \195\169TODO" ^ declaration) );
    ( "UTF8 punctuation is conservatively a word byte",
      count default 0 ("// TODO\226\128\148FIXME" ^ declaration) );
    ( "UTF8 separated words still match",
      count default 1 ("// \195\169 TODO \195\169" ^ declaration) );
    ( "multiline term separated by newline",
      count default 1 ("/* done\nTODO\nfinish */" ^ declaration) );
    ( "term split across lines does not match",
      count default 0 ("/* TO\nDO */" ^ declaration) );
    ("line context allowed", context_count [ Line ] 2);
    ("block context allowed", context_count [ Block ] 2);
    ("documentation context allowed", context_count [ Documentation ] 2);
    ("all contexts allowed", context_count [ Line; Block; Documentation ] 0);
    ("no contexts allowed", context_count [] 3);
    ( "ordinary block not documentation",
      count
        (configured ~allowed_contexts:[ Documentation ] ())
        1
        ("/* TODO */" ^ declaration) );
    ( "module documentation exempt",
      count
        (configured ~allowed_contexts:[ Documentation ] ())
        0
        ("/*** TODO */" ^ declaration) );
    ( "record documentation exempt",
      count
        (configured ~allowed_contexts:[ Documentation ] ())
        0 "type value = {/** TODO */ field: int}" );
    ( "interface documentation exempt",
      count ~kind:Source.Interface
        (configured ~allowed_contexts:[ Documentation ] ())
        0 "/** TODO */\nlet value: int" );
    ( "interface line still checked",
      count ~kind:Source.Interface
        (configured ~allowed_contexts:[ Documentation ] ())
        1 "// TODO\nlet value: int" );
    ("synthetic parsed doc context", synthetic_documentation false);
    ("synthetic parsed module context", synthetic_documentation true);
    ( "string contents never inspected",
      count default 0 "let value = \"// TODO /* FIXME */\"" );
    ( "custom terms ignore strings",
      count custom 0 "let value = \"REVIEW_ME BUG2\"" );
    ( "explicit doc attribute is not a comment",
      count default 0 "@res.doc(\"TODO\") let value = 1" );
    ( "documentation contains comment syntax",
      count default 1 ("/** Example // TODO */" ^ declaration) );
    ( "comment content cannot choose allowed context",
      count
        (configured ~allowed_contexts:[ Documentation ] ())
        1
        ("// documentation TODO" ^ declaration) );
    ( "multiple comments stay independent",
      count default 2 "// TODO\nlet value = 1 // FIXME\n" );
    ( "default policy exact equality",
      success (default = Ok Policy_rules.default_warning_policy) );
    ("empty terms invalid", invalid (configured ~terms:[] ()));
    ("empty term invalid", invalid (configured ~terms:[ "" ] ()));
    ("whitespace term invalid", invalid (configured ~terms:[ " TODO " ] ()));
    ("phrase term invalid", invalid (configured ~terms:[ "FIX ME" ] ()));
    ("punctuation term invalid", invalid (configured ~terms:[ "TODO:" ] ()));
    ("digit initial invalid", invalid (configured ~terms:[ "1TODO" ] ()));
    ("underscore initial invalid", invalid (configured ~terms:[ "_TODO" ] ()));
    ("nonASCII term invalid", invalid (configured ~terms:[ "\195\169TODO" ] ()));
    ("duplicate term invalid", invalid (configured ~terms:[ "todo"; "TODO" ] ()));
    ( "duplicate context invalid",
      invalid (configured ~allowed_contexts:[ Line; Line ] ()) );
    ( "message follows configured order without repeated terms",
      match inspect custom ("// BUG2 REVIEW_ME BUG2" ^ declaration) with
      | Ok [ diagnostic ] ->
          success
            (diagnostic.message
           = "This comment contains a warning term: REVIEW_ME, BUG2.")
      | _ -> Error "Expected one custom warning." );
    ( "line range preserves exact byte offsets",
      match inspect custom ("// REVIEW_ME" ^ declaration) with
      | Ok [ diagnostic ] ->
          success
            (diagnostic.range.start.byte_offset = 0
            && diagnostic.range.start.column = 1
            && diagnostic.range.finish.byte_offset = 12
            && diagnostic.range.finish.line = 1
            && diagnostic.range.finish.column = 13)
      | _ -> Error "Expected one located warning." );
    ( "block range preserves exact byte offsets",
      match inspect custom ("/* BUG2 */" ^ declaration) with
      | Ok [ diagnostic ] ->
          success
            (diagnostic.range.start.byte_offset = 0
            && diagnostic.range.finish.byte_offset = 10)
      | _ -> Error "Expected one located warning." );
  ]

let decode_config policy =
  Config_file.decode ~base:"/project" Rule_config.default
    (`Assoc [ ("warningComments", policy) ])

let configured_count ?(enabled = true) policy expected text =
  Result.bind (decode_config policy) (fun config ->
      Result.bind (Rule_config.set config ~id:"no-warning-comments" ~enabled)
        (fun config ->
          let source =
            Source.{ filename = "configured.res"; text; kind = Implementation }
          in
          Result.bind
            (Linter.lint_source_with_rules config source
            |> Result.map_error Lint_error.render)
            (fun diagnostics -> success (List.length diagnostics = expected))))

let config_checks =
  [
    ( "empty config policy defaults",
      success
        (Warning_config.decode (`Assoc [])
        = Ok Policy_rules.default_warning_policy) );
    ( "config terms only",
      configured_count
        (`Assoc [ ("terms", `List [ `String "REVIEW" ]) ])
        1
        ("// REVIEW" ^ declaration) );
    ( "config custom terms replace defaults",
      configured_count
        (`Assoc [ ("terms", `List [ `String "REVIEW" ]) ])
        0 ("// TODO" ^ declaration) );
    ( "config contexts only uses default terms",
      configured_count
        (`Assoc [ ("allowedContexts", `List [ `String "line" ]) ])
        1
        ("// TODO\n/* FIXME */" ^ declaration) );
    ( "config block context",
      configured_count
        (`Assoc [ ("allowedContexts", `List [ `String "block" ]) ])
        1
        ("// TODO\n/* FIXME */" ^ declaration) );
    ( "config documentation context",
      configured_count
        (`Assoc [ ("allowedContexts", `List [ `String "documentation" ]) ])
        0
        ("/** TODO */" ^ declaration) );
    ( "config rule disabled stays disabled",
      configured_count ~enabled:false
        (`Assoc [ ("terms", `List [ `String "REVIEW" ]) ])
        0
        ("// REVIEW" ^ declaration) );
    ( "config empty terms invalid",
      invalid (decode_config (`Assoc [ ("terms", `List []) ])) );
    ( "config empty term invalid",
      invalid (decode_config (`Assoc [ ("terms", `List [ `String "" ]) ])) );
    ( "config duplicate terms invalid",
      invalid
        (decode_config
           (`Assoc [ ("terms", `List [ `String "TODO"; `String "todo" ]) ])) );
    ( "config unknown context invalid",
      invalid
        (decode_config
           (`Assoc [ ("allowedContexts", `List [ `String "doc" ]) ])) );
    ( "config wrong context type invalid",
      invalid (decode_config (`Assoc [ ("allowedContexts", `List [ `Int 1 ]) ]))
    );
    ( "config duplicate contexts invalid",
      invalid
        (decode_config
           (`Assoc
              [ ("allowedContexts", `List [ `String "line"; `String "line" ]) ]))
    );
    ( "config terms must be an array",
      invalid (decode_config (`Assoc [ ("terms", `String "TODO") ])) );
    ( "config term must be string",
      invalid (decode_config (`Assoc [ ("terms", `List [ `Int 1 ]) ])) );
    ( "config contexts must be an array",
      invalid (decode_config (`Assoc [ ("allowedContexts", `String "line") ]))
    );
    ( "config unknown property invalid",
      invalid (decode_config (`Assoc [ ("term", `List [ `String "TODO" ]) ])) );
    ( "config duplicate property invalid",
      invalid
        (decode_config
           (`Assoc
              [
                ("terms", `List [ `String "TODO" ]);
                ("terms", `List [ `String "FIXME" ]);
              ])) );
    ("config null invalid", invalid (decode_config `Null));
    ("config array invalid", invalid (decode_config (`List [])));
    ( "config empty contexts allowed",
      configured_count
        (`Assoc [ ("allowedContexts", `List []) ])
        1 ("// TODO" ^ declaration) );
    ( "config all contexts allowed",
      configured_count
        (`Assoc
           [
             ( "allowedContexts",
               `List
                 [ `String "line"; `String "block"; `String "documentation" ] );
           ])
        0
        ("// TODO\n/* FIXME */\n/** HACK */" ^ declaration) );
    ( "replacement config omitted fields reset to defaults",
      Result.bind
        (decode_config
           (`Assoc
              [
                ("terms", `List [ `String "BUG" ]);
                ("allowedContexts", `List [ `String "line" ]);
              ]))
        (fun config ->
          Result.bind
            (Config_file.decode ~base:"/project" config
               (`Assoc [ ("warningComments", `Assoc []) ]))
            (fun config ->
              success
                ((Rule_config.options config).warning_comments
               = Policy_rules.default_warning_policy))) );
    ( "warning config preserves dependency options",
      Result.bind
        (Config_file.decode ~base:"/project" Rule_config.default
           (`Assoc
              [
                ("throwsDependencies", `List [ `String "deps" ]);
                ("warningComments", `Assoc []);
              ]))
        (fun config ->
          success
            ((Rule_config.options config).throws_dependencies
           = [ "/project/deps" ])) );
  ]

let () =
  let failed =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
      (checks @ config_checks)
  in
  List.iter prerr_endline failed;
  if failed <> [] then exit 1
