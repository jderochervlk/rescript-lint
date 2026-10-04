let position (value : Diagnostic.position) =
  `Assoc
    [
      ("line", `Int value.line);
      ("column", `Int value.column);
      ("byteOffset", `Int value.byte_offset);
    ]

let fix (value : Text_edit.t) =
  `Assoc
    [
      ("startByte", `Int value.start);
      ("endByte", `Int value.finish);
      ("text", `String value.text);
    ]

let diagnostic (value : Diagnostic.t) =
  `Assoc
    [
      ("rule", `String value.rule);
      ("severity", `String "error");
      ("message", `String value.message);
      ("filename", `String value.filename);
      ( "range",
        `Assoc
          [
            ("start", position value.range.start);
            ("end", position value.range.finish);
          ] );
      ( "help",
        Option.fold ~none:`Null
          ~some:(fun (help : Diagnostic.help) ->
            `Assoc
              [
                ("message", `String help.message);
                ( "url",
                  Option.fold ~none:`Null
                    ~some:(fun url -> `String url)
                    help.url );
              ])
          value.help );
      ( "symbol",
        Option.fold ~none:`Null
          ~some:(fun (symbol : Diagnostic.symbol) ->
            `Assoc
              [
                ("kind", `String (Diagnostic.kind_name symbol.kind));
                ("path", `String symbol.path);
              ])
          value.symbol );
      ("fixes", `List (List.map fix value.fixes));
    ]

let lint_kind = function
  | Lint_error.Read_error _ -> "read"
  | Write_error _ -> "write"
  | Fix_error _ -> "fix"
  | Unsupported_file _ -> "unsupported-file"
  | Parse_errors _ -> "parse"
  | Analysis_errors _ -> "analysis"

let lint_filename = function
  | Lint_error.Read_error { filename; _ }
  | Write_error { filename; _ }
  | Fix_error { filename; _ }
  | Unsupported_file filename ->
      filename
  | Parse_errors (first, _) | Analysis_errors (first, _) -> first.filename

let error = function
  | Report.Lint failure ->
      `Assoc
        [
          ("kind", `String (lint_kind failure));
          ("filename", `String (lint_filename failure));
          ("message", `String (Lint_error.render failure));
          ( "diagnostics",
            `List
              (List.map diagnostic
                 (Option.value ~default:[] (Lint_error.diagnostics failure))) );
        ]
  | Command failure ->
      `Assoc
        [
          ("kind", `String "command");
          ("filename", `Null);
          ("message", `String (Cli_command.error_message failure));
          ("diagnostics", `List []);
        ]

let encode (report : Report.t) =
  let outcome = Report.outcome report in
  let outcome_name =
    match outcome with
    | Report.Clean -> "clean"
    | Findings -> "findings"
    | Failed -> "failed"
  in
  Yojson.Basic.to_string
    (`Assoc
       [
         ("schemaVersion", `Int 1);
         ("outcome", `String outcome_name);
         ("exitCode", `Int (Report.exit_code outcome));
         ("diagnostics", `List (List.map diagnostic report.diagnostics));
         ("errors", `List (List.map error report.errors));
       ])

let render report =
  Report.{ stdout = [ encode report ]; stderr = []; outcome = outcome report }
