open Rescript_linter

let source text = Source.{ filename = "fix.res"; kind = Implementation; text }
let bad = "input->consume\ndone()\n"
let good = "input->consume\n\ndone()\n"
let edit start finish text = Text_edit.{ start; finish; text }
let is_error = function Error _ -> true | Ok _ -> false

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
    ( "plain source unchanged",
      Fixer.fix_source (source "let a = 0") = Ok (source "let a = 0", []) );
    ( "disabled spacing remains unchanged",
      match
        Rule_config.set Rule_config.default ~id:"blank-lines" ~enabled:false
      with
      | Error _ -> false
      | Ok rules ->
          Fixer.fix_source
            ~lint:(Linter.lint_source_with_rules rules)
            (source bad)
          = Ok (source bad, []) );
    ( "write error rendered",
      Lint_error.render (Write_error { filename = "a"; detail = "b" })
      = "a: Cannot write file: b" );
    ( "fix error rendered",
      Lint_error.render (Fix_error { filename = "a"; detail = "b" })
      = "a: Cannot apply fixes: b" );
  ]

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

let () =
  let checks =
    pipeline_checks () @ with_file file_checks @ with_file untouched_checks
    @ with_file link_checks @ with_file readonly_checks
  in
  let failures =
    List.filter_map
      (fun (name, passed) -> if passed then None else Some name)
      checks
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
