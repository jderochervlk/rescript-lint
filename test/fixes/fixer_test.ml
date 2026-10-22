open Rescript_linter

let source text = Source.{ filename = "fix.res"; kind = Implementation; text }
let bad = "input->consume\ndone()\n"
let good = "input->consume\n\ndone()\n"
let edit start finish text = Text_edit.{ start; finish; text }
let is_error = function Error _ -> true | Ok _ -> false
let preserve_layout (source : Source.t) = Ok source.text

let diagnostic edits =
  Diagnostic.
    {
      filename = "fix.res";
      rule = "test";
      message = "test";
      range =
        {
          start = { line = 1; column = 1; byte_offset = 0 };
          finish = { line = 1; column = 1; byte_offset = 0 };
        };
      help = None;
      symbol = None;
      fixes = edits;
    }

let pipeline_checks () =
  let invalid _ = Ok [ diagnostic [ edit (-1) 0 "" ] ] in
  let persistent _ = Ok [ diagnostic [ edit 0 0 "\n" ] ] in
  [
    ("no edits", Text_edit.apply "abc" [] = Ok "abc");
    ( "sorted disjoint edits",
      Text_edit.apply "abcd" [ edit 4 4 "!"; edit 1 2 "B" ] = Ok "aBcd!" );
    ( "duplicate edits",
      Text_edit.apply "a" [ edit 0 0 "x"; edit 0 0 "x" ] = Ok "xa" );
    ( "overlap",
      Text_edit.apply "abc" [ edit 0 2 ""; edit 1 3 "" ]
      = Error Overlapping_edits );
    ( "conflicting insertion",
      Text_edit.apply "abc" [ edit 1 1 "x"; edit 1 1 "y" ]
      = Error Overlapping_edits );
    ( "negative range",
      Text_edit.apply "a" [ edit (-1) 0 "" ] = Error Invalid_range );
    ("reversed range", Text_edit.apply "a" [ edit 1 0 "" ] = Error Invalid_range);
    ("past EOF", Text_edit.apply "a" [ edit 0 2 "" ] = Error Invalid_range);
    ( "touching edits",
      Text_edit.apply "abc" [ edit 0 1 "A"; edit 1 2 "B" ] = Ok "ABc" );
    ( "invalid edit fails closed",
      is_error (Fixer.fix_source ~lint:invalid (source bad)) );
    ( "nonconvergent fixes fail closed",
      is_error (Fixer.fix_source ~lint:persistent (source bad)) );
    ( "formatter conflicts fail closed",
      is_error (Fixer.fix_source ~format:(fun _ -> Ok bad) (source bad)) );
    ( "formatter invalid output fails closed",
      is_error (Fixer.fix_source ~format:(fun _ -> Ok "let =") (source bad)) );
    ("syntax error", is_error (Fixer.fix_source (source "let =")));
    ( "analysis error",
      is_error (Fixer.fix_source (source "@throws(42) let read = () => 0")) );
    ( "source without findings is formatted",
      Fixer.fix_source (source "let  a=0") = Ok (source "let a = 0\n", []) );
    ( "disabled spacing still formats source",
      match
        Rule_config.set Rule_config.default ~id:"blank-lines" ~enabled:false
      with
      | Error _ -> false
      | Ok rules ->
          Fixer.fix_source
            ~lint:(Linter.lint_source_with_rules rules)
            (source "let  value=input->convert\nconsume(value)")
          = Ok (source "let value = input->convert\nconsume(value)\n", []) );
    ( "write error rendered",
      Lint_error.render (Write_error { filename = "a"; detail = "b" })
      = "a: Cannot write file: b" );
    ( "fix error rendered",
      Lint_error.render (Fix_error { filename = "a"; detail = "b" })
      = "a: Cannot apply fixes: b" );
  ]

let traced_fix ~lint ~format input =
  (* Local state records calls to the injected capabilities, including order. *)
  let calls = ref [] in
  let record stage (source : Source.t) =
    calls := (stage, source.text) :: !calls
  in
  let lint source =
    record "lint" source;
    lint source
  in
  let format source =
    record "format" source;
    format source
  in
  let result = Fixer.fix_source ~lint ~format input in
  (result, List.rev !calls)

let proposed_fixes = [ diagnostic [ edit 0 (String.length bad) good ] ]

let callback_success_checks () =
  let original = "let original=0\n" in
  let formatted = "let formatted = 0\n" in
  let lint (source : Source.t) =
    Ok
      (if source.text = original then
         [ diagnostic [ edit 0 (String.length original) "let stale = 0\n" ] ]
       else if source.text = bad then proposed_fixes
       else [])
  in
  let format (source : Source.t) =
    Ok (if source.text = original then bad else formatted)
  in
  let result, calls = traced_fix ~lint ~format (source original) in
  let finding = diagnostic [] in
  let formatting_only, minimal_calls =
    traced_fix
      ~lint:(fun source ->
        Ok (if source.Source.text = formatted then [ finding ] else []))
      ~format:(fun _ -> Ok formatted)
      (source original)
  in
  [
    ( "formatting precedes edits and discards original-source offsets",
      result = Ok (source good, [])
      && calls
         = [
             ("lint", original);
             ("format", original);
             ("lint", bad);
             ("lint", good);
             ("format", good);
             ("lint", formatted);
           ] );
    ( "formatting-only output returns recomputed findings without final \
       validation",
      formatting_only = Ok (source formatted, [ finding ])
      && minimal_calls
         = [ ("lint", original); ("format", original); ("lint", formatted) ] );
  ]

let lint_failure_cases error =
  let lint (source : Source.t) =
    if source.text = bad then Ok proposed_fixes else Error error
  in
  [
    ( "initial lint failure",
      (fun _ -> Error error),
      (fun _ -> Ok good),
      [ ("lint", bad) ] );
    ( "re-lint failure",
      lint,
      preserve_layout,
      [ ("lint", bad); ("format", bad); ("lint", bad); ("lint", good) ] );
    ( "initial formatted lint failure",
      lint,
      (fun _ -> Ok "let formatted = 0\n"),
      [ ("lint", bad); ("format", bad); ("lint", "let formatted = 0\n") ] );
  ]

let formatter_failure_cases error =
  [
    ( "initial formatter failure",
      (fun source ->
        if source.Source.text = bad then Ok proposed_fixes else Ok []),
      (fun _ -> Error error),
      [ ("lint", bad); ("format", bad) ] );
    ( "final formatter failure",
      (fun source ->
        if source.Source.text = bad then Ok proposed_fixes else Ok []),
      (fun source -> if source.Source.text = bad then Ok bad else Error error),
      [
        ("lint", bad);
        ("format", bad);
        ("lint", bad);
        ("lint", good);
        ("format", good);
      ] );
    ( "final formatted lint failure",
      (fun source ->
        if source.Source.text = bad then Ok proposed_fixes
        else if source.text = good then Ok []
        else Error error),
      (fun source ->
        Ok (if source.Source.text = bad then bad else "let formatted = 0\n")),
      [
        ("lint", bad);
        ("format", bad);
        ("lint", bad);
        ("lint", good);
        ("format", good);
        ("lint", "let formatted = 0\n");
      ] );
  ]

let callback_failure_checks () =
  let error =
    Lint_error.Fix_error { filename = "fix.res"; detail = "sentinel" }
  in
  let cases = lint_failure_cases error @ formatter_failure_cases error in
  List.map
    (fun (name, lint, format, expected_calls) ->
      let result, calls = traced_fix ~lint ~format (source bad) in
      ( name ^ " propagates unchanged and stops the pipeline",
        result = Error error && calls = expected_calls ))
    cases

let formatter_parse_checks () =
  let result, calls =
    traced_fix ~lint:(fun _ -> Ok []) ~format:(fun _ -> Ok "let =") (source bad)
  in
  let final, final_calls =
    traced_fix
      ~lint:(fun source ->
        Ok (if source.Source.text = bad then proposed_fixes else []))
      ~format:(fun source ->
        Ok (if source.Source.text = bad then bad else "let ="))
      (source bad)
  in
  [
    ( "formatter output is parsed before candidate lint",
      (match result with
        | Error (Lint_error.Parse_errors _) -> true
        | _ -> false)
      && calls = [ ("lint", bad); ("format", bad) ] );
    ( "final formatter output is parsed before validation lint",
      (match final with
        | Error (Lint_error.Parse_errors _) -> true
        | _ -> false)
      && final_calls
         = [
             ("lint", bad);
             ("format", bad);
             ("lint", bad);
             ("lint", good);
             ("format", good);
           ] );
    ( "final formatter spacing guard remains strict",
      Fixer.fix_source ~format:(fun _ -> Ok bad) (source bad)
      = Error
          (Lint_error.Fix_error
             {
               filename = "fix.res";
               detail =
                 "The ReScript formatter would leave missing blank lines after \
                  fixes. File left unchanged.";
             }) );
  ]

let formatted_output_checks () =
  let interface text =
    Source.{ filename = "api.resi"; kind = Interface; text }
  in
  let cases =
    [
      ( "collapsed multiline call needs no following separator",
        source "consume(\n  first,\n  second,\n)\ndone()\n",
        source "consume(first, second)\ndone()\n" );
      ( "collapsed interface signature needs no following separator",
        interface "let consume: (\n  int,\n  string,\n) => unit\nlet next: int",
        interface "let consume: (int, string) => unit\nlet next: int\n" );
      ( "formatter supplies LF and final newline",
        source "let  value=input->convert\r\nconsume(value)",
        source "let value = input->convert\n\nconsume(value)\n" );
    ]
  in
  List.map
    (fun (name, input, expected) ->
      (name, Fixer.fix_source input = Ok (expected, [])))
    cases

let formatted_diagnostic_checks () =
  let prefix = "let f = () => {\n  let value = 1\n  value\n}\n\n" in
  let result =
    Fixer.fix_source (source "let f=()=>{let value=1;value}\nConsole.log(1)\n")
  in
  [
    ( "remaining diagnostics use formatted and fixed positions",
      match result with
      | Ok (fixed, [ finding ]) ->
          fixed = source (prefix ^ "Console.log(1)\n")
          && finding.rule = "no-console"
          && finding.range.start.line = 6
          && finding.range.start.column = 1
          && finding.range.start.byte_offset = String.length prefix
      | Ok _ | Error _ -> false );
  ]

let original_error_checks () =
  [
    ("parse", "let first=0\n\nlet =");
    ("analysis", "let first=0\n\n@throws(42) let read=()=>0");
  ]
  |> List.map (fun (name, text) ->
      let input = source text in
      ( "original " ^ name ^ " error locations survive preflight",
        match (Linter.lint_source input, Fixer.fix_source input) with
        | Error expected, Error actual -> actual = expected
        | _ -> false ))

let write filename text =
  Out_channel.with_open_bin filename (fun channel -> output_string channel text)

let read filename = In_channel.with_open_bin filename In_channel.input_all

let with_file run =
  let filename = Filename.temp_file "rescript-fix-" ".res" in
  Fun.protect ~finally:(fun () -> Sys.remove filename) (fun () -> run filename)

let file_checks filename =
  write filename bad;
  Unix.chmod filename 0o640;
  let fixed = Fixer.fix_file filename in
  let once = read filename in
  let permissions = (Unix.stat filename).st_perm land 0o777 in
  let twice = Fixer.fix_file filename in
  let original = Source.{ filename; text = once; kind = Implementation } in
  write filename "let changed = 1\n";
  let stale = Source.write ~original good in
  [
    ("file fixed", fixed = Ok [] && once = good);
    ("permissions preserved", Sys.win32 || permissions = 0o640);
    ("file idempotent", twice = Ok []);
    ( "stale writes refused",
      is_error stale && read filename = "let changed = 1\n" );
  ]

let untouched_checks filename =
  let syntax = "let =\n" in
  write filename syntax;
  let parse_failure = Fixer.fix_file filename in
  let syntax_unchanged = read filename = syntax in
  let analysis = "@throws(42)\nlet read = () => 0\n" in
  write filename analysis;
  let analysis_failure = Fixer.fix_file filename in
  let analysis_unchanged = read filename = analysis in
  write filename "input->Console.log\ndone()\n";
  let remaining = Fixer.fix_file filename in
  [
    ("syntax failures do not write", is_error parse_failure && syntax_unchanged);
    ( "analysis failures do not write",
      is_error analysis_failure && analysis_unchanged );
    ( "nonfixable findings remain",
      match remaining with Ok [ d ] -> d.rule = "no-console" | _ -> false );
    ( "spacing fixed despite findings",
      read filename = "input->Console.log\n\ndone()\n" );
    ("unsupported files fail", is_error (Fixer.fix_file (filename ^ ".txt")));
    ("missing files fail", is_error (Fixer.fix_file (filename ^ ".missing.res")));
    ( "missing write target fails",
      is_error
        (Source.write
           ~original:
             Source.
               {
                 filename = filename ^ ".missing.res";
                 text = "";
                 kind = Implementation;
               }
           "") );
  ]

let link_checks filename =
  if Sys.win32 then []
  else
    let alias = filename ^ ".alias.res" in
    write filename bad;
    Unix.symlink filename alias;
    let symlink =
      Fun.protect
        ~finally:(fun () -> Sys.remove alias)
        (fun () -> Fixer.fix_file alias)
    in
    Unix.link filename alias;
    let hardlink =
      Fun.protect
        ~finally:(fun () -> Sys.remove alias)
        (fun () -> Fixer.fix_file filename)
    in
    [
      ("symlinks refused", is_error symlink && read filename = bad);
      ("hardlinks refused", is_error hardlink && read filename = bad);
    ]

let readonly_checks filename =
  write filename bad;
  Unix.chmod filename 0o444;
  let result =
    Fun.protect
      ~finally:(fun () -> Unix.chmod filename 0o600)
      (fun () -> Fixer.fix_file filename)
  in
  [ ("read-only files refused", is_error result && read filename = bad) ]

let formatter_expansion_checks filename =
  let input =
    "let f = () => {let value = 1; value}\n\
     let next = 0\n\
     input->consume\n\
     done()\n"
  in
  let expected =
    "let f = () => {\n\
    \  let value = 1\n\
    \  value\n\
     }\n\n\
     let next = 0\n\
     input->consume\n\n\
     done()\n"
  in
  write filename input;
  let result = Fixer.fix_file filename in
  [
    ( "automatic formatting separates expanded rows",
      result = Ok [] && read filename = expected );
    ( "automatic formatting and fixing remain idempotent",
      Fixer.fix_file filename = Ok [] && read filename = expected );
  ]

let formatting_only_file_checks filename =
  write filename "let  value=0";
  let result = Fixer.fix_file filename in
  [
    ( "formatting-only output is written",
      result = Ok [] && read filename = "let value = 0\n" );
    ( "formatting-only file remains idempotent",
      Fixer.fix_file filename = Ok [] && read filename = "let value = 0\n" );
  ]

let suppressed_inner_spacing_checks () =
  let input =
    source
      "let f = () => {input->consume; done()} // rescript-lint-disable-line \
       blank-lines -- intentional\n\
       let next = 0\n"
  in
  [
    ( "suppressed inner spacing does not create an outer finding",
      Linter.lint_source input = Ok [] );
    ( "suppressed inner spacing does not expand the enclosing declaration",
      Fixer.fix_source ~format:preserve_layout input = Ok (input, []) );
  ]

let formatted_suppression_checks () =
  let input =
    source
      "// rescript-lint-disable blank-lines -- intentional\n\
       let f=()=>{input->consume;done()}\n\
       let next=0\n\
       // rescript-lint-enable blank-lines\n"
  in
  let expected =
    source
      "// rescript-lint-disable blank-lines -- intentional\n\
       let f = () => {\n\
      \  input->consume\n\
      \  done()\n\
       }\n\
       let next = 0\n\
       // rescript-lint-enable blank-lines\n"
  in
  [
    ( "region suppression is reevaluated after formatting",
      Fixer.fix_source input = Ok (expected, []) );
  ]

let convergence_guard_checks () =
  let lint _ = Ok [ diagnostic [ edit 0 0 "" ] ] in
  let unchanged, unchanged_calls =
    traced_fix ~lint ~format:preserve_layout (source bad)
  in
  let exhausted, calls =
    traced_fix
      ~lint:(fun _ -> Ok [ diagnostic [ edit 0 0 "\n" ] ])
      ~format:preserve_layout (source bad)
  in
  [
    ( "nonprogressing edits fail without final formatting",
      unchanged
      = Error
          (Lint_error.Fix_error
             {
               filename = "fix.res";
               detail = "Spacing fixes did not converge. File left unchanged.";
             })
      && List.map fst unchanged_calls = [ "lint"; "format"; "lint" ] );
    ( "perpetual edits stop after ten batches without final formatting",
      is_error exhausted
      && List.map fst calls
         = [ "lint"; "format" ] @ List.init 11 (fun _ -> "lint") );
  ]

let cascade_validation_checks () =
  let input = source "let f = () => {input->consume; done()}\nlet next = 0\n" in
  let expected =
    source "let f = () => {input->consume; \n\ndone()}\n\nlet next = 0\n"
  in
  let result, calls =
    traced_fix ~lint:Linter.lint_source ~format:preserve_layout input
  in
  [
    ( "cascade applies both batches before final formatting once",
      result = Ok (expected, [])
      && List.map fst calls
         = [ "lint"; "format"; "lint"; "lint"; "lint"; "format"; "lint" ] );
  ]

let source_boundary_checks () =
  let input = source "consume(switch v {| _ => v}, input->convert)\ndone()\n" in
  let findings =
    Result.map
      (List.filter (fun (d : Diagnostic.t) -> d.rule = "blank-lines"))
      (Linter.lint_source input)
  in
  [
    ( "nested expression kinds do not require spacing after a single-line call",
      findings = Ok [] );
  ]

let () =
  let checks =
    pipeline_checks () @ callback_success_checks () @ callback_failure_checks ()
    @ formatter_parse_checks () @ formatted_output_checks ()
    @ formatted_diagnostic_checks ()
    @ original_error_checks () @ with_file file_checks
    @ with_file untouched_checks @ with_file link_checks
    @ with_file readonly_checks
    @ with_file formatter_expansion_checks
    @ with_file formatting_only_file_checks
    @ suppressed_inner_spacing_checks ()
    @ formatted_suppression_checks ()
    @ convergence_guard_checks ()
    @ cascade_validation_checks ()
    @ source_boundary_checks ()
  in
  let failures =
    List.filter_map
      (fun (name, passed) -> if passed then None else Some name)
      checks
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
