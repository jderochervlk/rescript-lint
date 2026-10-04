open Rescript_linter

let known_rules =
  [ "no-console"; "no-debugger"; "blank-lines"; "test/no-focused-tests" ]

let source ?(kind = Source.Implementation) text =
  Source.{ filename = "suppression.res"; text; kind }

let lint source document =
  Banned_api.check ~rules:[ No_console.rule ] ~source document.Parser.tree
  @ List.filter
      (fun (diagnostic : Diagnostic.t) -> diagnostic.rule = "no-debugger")
      (Exception_rules.check ~source document.tree)

let run ?kind text =
  let source = source ?kind text in
  Result.map
    (fun document ->
      Suppressions.apply ~known_rules ~source document (lint source document))
    (Parser.parse_document source)

let check ?kind ~console ~debugger ~audit text =
  match run ?kind text with
  | Error error -> Error (Lint_error.render error)
  | Ok diagnostics ->
      let count rule =
        List.length
          (List.filter
             (fun (item : Diagnostic.t) -> item.rule = rule)
             diagnostics)
      in
      let actual =
        (count "no-console", count "no-debugger", count "suppression")
      in
      if actual = (console, debugger, audit) then Ok ()
      else
        Error
          (Printf.sprintf
             "Expected %d console/%d debugger/%d audits; got %s for %s" console
             debugger audit
             (String.concat " | " (List.map Diagnostic.render diagnostics))
             text)

let clean = check ~console:0 ~debugger:0 ~audit:0
let audit = check ~console:0 ~debugger:0 ~audit:1
let remains = check ~console:1 ~debugger:0 ~audit:1

let preserves_failures rule =
  let source =
    source ("// rescript-lint-disable-next-line " ^ rule ^ "\nConsole.log(1)")
  in
  match Parser.parse_document source with
  | Error error -> Error (Lint_error.render error)
  | Ok document ->
      let incoming =
        lint source document
        |> List.map (fun (item : Diagnostic.t) -> { item with rule })
      in
      let actual =
        Suppressions.apply ~known_rules:(rule :: known_rules) ~source document
          incoming
      in
      if
        List.exists (fun (item : Diagnostic.t) -> item.rule = rule) actual
        && List.length actual = 2
      then Ok ()
      else Error ("Suppressed failure " ^ rule)

let fixes_removed =
  let source =
    source "Console.log(1) // rescript-lint-disable-line no-console"
  in
  match Parser.parse_document source with
  | Error error -> Error (Lint_error.render error)
  | Ok document ->
      let incoming =
        lint source document
        |> List.map (fun (item : Diagnostic.t) ->
            {
              item with
              help = None;
              symbol = None;
              fixes = [ Text_edit.{ start = 0; finish = 7; text = "Changed" } ];
            })
      in
      let actual = Suppressions.apply ~known_rules ~source document incoming in
      let edits =
        List.concat_map (fun (item : Diagnostic.t) -> item.fixes) actual
      in
      if actual = [] && Text_edit.apply source.text edits = Ok source.text then
        Ok ()
      else Error "Suppressed diagnostic retained a fix"

let foreign_file =
  let source =
    source "// rescript-lint-disable-next-line no-console\nConsole.log(1)"
  in
  match Parser.parse_document source with
  | Error error -> Error (Lint_error.render error)
  | Ok document ->
      let incoming =
        lint source document
        |> List.map (fun (item : Diagnostic.t) ->
            { item with filename = "other.res" })
      in
      let actual = Suppressions.apply ~known_rules ~source document incoming in
      if
        List.length actual = 2
        && List.exists
             (fun (item : Diagnostic.t) -> item.filename = "other.res")
             actual
      then Ok ()
      else Error "A directive affected a different source file"

let reason_preserved =
  match
    run
      "// rescript-lint-disable-next-line no-console -- tracked  reason -- \
       details\n\
       let x = 1"
  with
  | Ok [ item ]
    when item.message
         = "Unused suppression for no-console. Reason: tracked  reason -- \
            details" ->
      Ok ()
  | _ -> Error "Reason text was not preserved"

let exact_range =
  let comment = "// rescript-lint-disable-next-line unknown" in
  match run (comment ^ "\nlet x = 1") with
  | Ok [ item ]
    when item.range.start.line = 1
         && item.range.start.column = 1
         && item.range.start.byte_offset = 0
         && item.range.finish.byte_offset = String.length comment
         && item.filename = "suppression.res"
         && item.fixes = [] ->
      Ok ()
  | _ -> Error "Audit range mismatch"

let fixing_preserves_suppression ~text ~expected =
  match Fixer.fix_source (source text) with
  | Error error -> Error (Lint_error.render error)
  | Ok (fixed, diagnostics) ->
      if fixed.text = expected && diagnostics = [] then Ok ()
      else
        Error
          (Printf.sprintf "Expected fixed text %S without findings; got %S: %s"
             expected fixed.text
             (String.concat " | " (List.map Diagnostic.render diagnostics)))

let checks =
  [
    ("no directives", check ~console:1 ~debugger:0 ~audit:0 "Console.log(1)");
    ( "same-line trailing directive",
      clean "Console.log(1) // rescript-lint-disable-line no-console" );
    ( "same-line preceding block",
      clean "/* rescript-lint-disable-line no-console */ Console.log(1)" );
    ( "disable line means its own line",
      remains "// rescript-lint-disable-line no-console\nConsole.log(1)" );
    ( "next line",
      clean "// rescript-lint-disable-next-line no-console\nConsole.log(1)" );
    ( "next syntax line skips blanks",
      clean "// rescript-lint-disable-next-line no-console\n\n\nConsole.log(1)"
    );
    ( "next syntax line skips comments",
      clean
        "// rescript-lint-disable-next-line no-console\n\
         // explanation\n\
         /* another explanation */\n\
         Console.log(1)" );
    ( "next syntax line skips doc comments",
      clean
        "// rescript-lint-disable-next-line no-console\n\
         /** documented value */\n\
         let value = Console.log(1)" );
    ( "next syntax line skips module comments",
      clean
        "// rescript-lint-disable-next-line no-console\n\
         /*** documented module */\n\
         Console.log(1)" );
    ( "comment and code next line",
      clean
        "// rescript-lint-disable-next-line no-console\n\
         /* note */ Console.log(1)" );
    ( "next-line does not reach second syntax line",
      remains
        "// rescript-lint-disable-next-line no-console\n\
         let value = 1\n\
         Console.log(value)" );
    ( "next-line no target",
      audit "// rescript-lint-disable-next-line no-console" );
    ( "next-line comments only",
      audit "// rescript-lint-disable-next-line no-console\n// explanation\n" );
    ( "multi-line comment directive",
      clean "/* rescript-lint-disable-next-line\n no-console */\nConsole.log(1)"
    );
    ( "closed region",
      check ~console:1 ~debugger:0 ~audit:0
        "// rescript-lint-disable no-console\n\
         Console.log(1)\n\
         // rescript-lint-enable no-console\n\
         Console.log(2)" );
    ( "region through EOF",
      clean
        "// rescript-lint-disable no-console\nConsole.log(1)\nConsole.log(2)" );
    ( "region starts at directive",
      check ~console:1 ~debugger:0 ~audit:0
        "Console.log(0)\n// rescript-lint-disable no-console\nConsole.log(1)" );
    ( "same-line region boundaries",
      check ~console:1 ~debugger:0 ~audit:0
        "/* rescript-lint-disable no-console */ Console.log(1); /* \
         rescript-lint-enable no-console */ Console.log(2)" );
    ( "nested regions",
      clean
        "// rescript-lint-disable no-console\n\
         Console.log(1)\n\
         // rescript-lint-disable no-console\n\
         Console.log(2)\n\
         // rescript-lint-enable no-console\n\
         Console.log(3)\n\
         // rescript-lint-enable no-console" );
    ( "redundant outer region unused",
      audit
        "// rescript-lint-disable no-console\n\
         // rescript-lint-disable no-console\n\
         Console.log(1)\n\
         // rescript-lint-enable no-console\n\
         // rescript-lint-enable no-console" );
    ( "unmatched enable",
      audit "// rescript-lint-enable no-console\nlet value = 1" );
    ( "double enable",
      audit
        "// rescript-lint-disable no-console\n\
         Console.log(1)\n\
         // rescript-lint-enable no-console\n\
         // rescript-lint-enable no-console" );
    ( "unused region",
      audit
        "// rescript-lint-disable no-console\n\
         let value = 1\n\
         // rescript-lint-enable no-console" );
    ( "unused EOF region",
      audit "// rescript-lint-disable no-console\nlet value = 1" );
    ( "multiple IDs comma",
      clean
        "// rescript-lint-disable-next-line no-console, no-debugger\n\
         {Console.log(1); %debugger}" );
    ( "multiple IDs whitespace",
      clean
        "// rescript-lint-disable-next-line no-console no-debugger\n\
         {Console.log(1); %debugger}" );
    ( "multiple IDs with tab",
      clean
        "// rescript-lint-disable-next-line\tno-console\tno-debugger\n\
         {Console.log(1); %debugger}" );
    ( "per-ID unused auditing",
      audit
        "// rescript-lint-disable-next-line no-console, no-debugger\n\
         Console.log(1)" );
    ( "region partial enable",
      check ~console:1 ~debugger:0 ~audit:0
        "// rescript-lint-disable no-console no-debugger\n\
         Console.log(1)\n\
         // rescript-lint-enable no-console\n\
         {Console.log(2); %debugger}" );
    ( "unknown ID",
      remains "// rescript-lint-disable-next-line no-consol\nConsole.log(1)" );
    ( "mixed unknown invalidates directive",
      remains
        "// rescript-lint-disable-next-line no-console, nope\nConsole.log(1)" );
    ( "all-rule wildcard unavailable",
      remains "// rescript-lint-disable-next-line *\nConsole.log(1)" );
    ( "missing rule ID",
      remains "// rescript-lint-disable-next-line\nConsole.log(1)" );
    ( "unknown command",
      remains "// rescript-lint-disable-next-lines no-console\nConsole.log(1)"
    );
    ("empty command", audit "// rescript-lint\nlet value = 1");
    ( "space instead of command separator",
      audit "// rescript-lint disable no-console\nlet value = 1" );
    ( "duplicate ID",
      remains
        "// rescript-lint-disable-next-line no-console no-console\n\
         Console.log(1)" );
    ( "leading comma",
      remains "// rescript-lint-disable-next-line ,no-console\nConsole.log(1)"
    );
    ( "trailing comma",
      remains "// rescript-lint-disable-next-line no-console,\nConsole.log(1)"
    );
    ( "double comma",
      remains
        "// rescript-lint-disable-next-line no-console,,no-debugger\n\
         Console.log(1)" );
    ( "reason supported",
      clean
        "// rescript-lint-disable-next-line no-console -- diagnostic bridge\n\
         Console.log(1)" );
    ( "empty reason malformed",
      remains "// rescript-lint-disable-next-line no-console --\nConsole.log(1)"
    );
    ( "reason preserves punctuation",
      clean
        "// rescript-lint-disable-next-line no-console -- see -- details, \
         punctuation\n\
         Console.log(1)" );
    ("reason preserved in audit", reason_preserved);
    ( "embedded text not directive",
      check ~console:1 ~debugger:0 ~audit:0
        "// Example: rescript-lint-disable-next-line no-console\nConsole.log(1)"
    );
    ( "similarly named tool ignored",
      clean "// rescript-linter is a tool\nlet value = 1" );
    ( "string is not directive",
      clean "let value = \"// rescript-lint-disable no-console\"" );
    ( "doc comment not directive",
      check ~console:1 ~debugger:0 ~audit:0
        "/** rescript-lint-disable-next-line no-console */\n\
         let value = Console.log(1)" );
    ( "module comment not directive",
      check ~console:1 ~debugger:0 ~audit:0
        "/*** rescript-lint-disable-next-line no-console */\nConsole.log(1)" );
    ( "attribute not directive",
      check ~console:1 ~debugger:0 ~audit:0
        "@res.doc(\"rescript-lint-disable-next-line no-console\") let value = \
         Console.log(1)" );
    ( "CRLF comments",
      clean
        "// rescript-lint-disable-next-line no-console\r\n\
         \r\n\
         // explanation\r\n\
         Console.log(1)\r\n" );
    ( "Unicode before directive",
      clean
        "let value = \"\240\159\152\128\"; Console.log(value) // \
         rescript-lint-disable-line no-console" );
    ( "closer line suppression wins",
      audit
        "// rescript-lint-disable-next-line no-console\n\
         Console.log(1) // rescript-lint-disable-line no-console" );
    ( "line suppression beats region",
      audit
        "// rescript-lint-disable no-console\n\
         Console.log(1) // rescript-lint-disable-line no-console" );
    ( "all findings on target line",
      clean
        "// rescript-lint-disable-next-line no-console\n\
         {Console.log(1); Console.log(2)}" );
    ( "primary start line only",
      clean
        "// rescript-lint-disable-next-line no-console\nConsole.log(\n  1\n)" );
    ( "interface unused audit",
      check ~kind:Source.Interface ~console:0 ~debugger:0 ~audit:1
        "// rescript-lint-disable-next-line no-console\nlet value: int" );
    ("syntax cannot be suppressed", preserves_failures "syntax");
    ("analysis cannot be suppressed", preserves_failures "adapter-analysis");
    ("audit cannot be suppressed", preserves_failures "suppression");
    ("fixes removed", fixes_removed);
    ( "fixer leaves suppressed spacing unchanged",
      let text =
        "let value = read()->convert\n\
         // rescript-lint-disable-line blank-lines\n\
         finish(value)\n"
      in
      fixing_preserves_suppression ~text ~expected:text );
    ( "fixer applies unsuppressed spacing beside suppressed spacing",
      fixing_preserves_suppression
        ~text:
          "let value = read()->convert\n\
           // rescript-lint-disable-line blank-lines\n\
           switch value {\n\
           | _ => consume(value)\n\
           }\n\
           finish()\n"
        ~expected:
          "let value = read()->convert\n\
           // rescript-lint-disable-line blank-lines\n\
           switch value {\n\
           | _ => consume(value)\n\
           }\n\n\
           finish()\n" );
    ("foreign filename unaffected", foreign_file);
    ("exact audit range", exact_range);
  ]

let () =
  let failures =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
      checks
  in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
