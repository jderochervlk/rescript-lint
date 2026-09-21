type request = { files : string list; rules : Rule_config.t }
type format = Human | Json
type watch = { files : string list; fix : bool; rules : Rule_config.t }

type t =
  | Help
  | Version
  | List_rules
  | Lint of request
  | Fix of request
  | Watch of watch
  | Language_server of Rule_config.t

type error =
  | Missing_files
  | Unknown_option of string
  | Invalid_lsp_arguments
  | Invalid_rule of string
  | Missing_rule of string
  | Missing_format
  | Invalid_format of string
  | Unsupported_format_mode

let version = "0.1.0-alpha.2"

let help =
  "Usage: rescript-lint [--fix] [--watch] [--] FILE.res [FILE.resi ...]\n\
  \       rescript-lint lsp --stdio\n\n\
   Options:\n\
  \  --format human|json  Select diagnostic output (default: human)\n\
  \  -h, --help     Show this help\n\
  \  --version      Show the version\n\
  \  --fix          Apply safe fixes, then report remaining errors\n\
  \  -w, --watch    Re-run when an input file changes\n\
  \  --list-rules   List rules and their default activation\n\
  \  --enable-rule ID   Enable a rule (repeatable)\n\
  \  --disable-rule ID  Disable a rule (repeatable)\n\
  \  --config FILE  Read rule and project options from JSON\n\
  \  --project DIR  Read project sources and interfaces\n\
  \  --jsx-runtime react-dom  Select the React DOM adapter\n\
  \  --test-framework rescript-vitest-3  Select the test adapter\n\
  \  --throws-runtime rescript-12.3.1  Select the throws runtime adapter\n\
  \  --             Treat remaining arguments as file paths\n"

let files_command ~rules ~fix ~watch = function
  | [] when Option.is_none (Rule_config.options rules).root ->
      Error Missing_files
  | files when watch -> Ok (Watch { files; fix; rules })
  | files -> Ok (if fix then Fix { files; rules } else Lint { files; rules })

let rec parse_files rules fix watch reversed = function
  | [] -> files_command ~rules ~fix ~watch (List.rev reversed)
  | "--" :: rest ->
      files_command ~rules ~fix ~watch (List.rev_append reversed rest)
  | "--fix" :: rest -> parse_files rules true watch reversed rest
  | ("--watch" | "-w") :: rest -> parse_files rules fix true reversed rest
  | argument :: _ when String.starts_with ~prefix:"-" argument ->
      Error (Unknown_option argument)
  | file :: rest -> parse_files rules fix watch (file :: reversed) rest

let parse_command rules = function
  | [ "--help" ] | [ "-h" ] -> Ok Help
  | [ "--version" ] -> Ok Version
  | [ "--list-rules" ] -> Ok List_rules
  | [ "lsp"; "--stdio" ] -> Ok (Language_server rules)
  | "lsp" :: _ -> Error Invalid_lsp_arguments
  | arguments -> parse_files rules false false [] arguments

let rec parse_rules rules reversed = function
  | [] -> parse_command rules (List.rev reversed)
  | "--" :: rest ->
      parse_command rules (List.rev_append reversed ("--" :: rest))
  | (("--enable-rule" | "--disable-rule") as option) :: rest ->
      parse_rule rules reversed option rest
  | (( "--config" | "--project" | "--jsx-runtime" | "--test-framework"
     | "--throws-runtime" ) as option)
    :: rest ->
      parse_setting rules reversed option rest
  | argument :: rest -> parse_rules rules (argument :: reversed) rest

and parse_rule rules reversed option = function
  | [] -> Error (Missing_rule option)
  | id :: _ when String.starts_with ~prefix:"-" id ->
      Error (Missing_rule option)
  | id :: rest ->
      let enabled = String.equal option "--enable-rule" in
      let configured =
        Rule_config.set rules ~id ~enabled
        |> Result.map_error (fun message -> Invalid_rule message)
      in
      Result.bind configured (fun rules -> parse_rules rules reversed rest)

and parse_setting rules reversed option = function
  | [] -> Error (Invalid_rule (option ^ " requires a value."))
  | value :: _ when String.starts_with ~prefix:"-" value ->
      Error (Invalid_rule (option ^ " requires a value."))
  | value :: rest ->
      let configured =
        if option = "--config" then Config_file.load rules value
        else
          let key =
            match option with
            | "--project" -> "root"
            | "--jsx-runtime" -> "jsxRuntime"
            | "--throws-runtime" -> "throwsRuntime"
            | _ -> "testFramework"
          in
          Config_file.decode ~base:"." rules (`Assoc [ (key, `String value) ])
      in
      let configured =
        Result.map_error (fun message -> Invalid_rule message) configured
      in
      Result.bind configured (fun rules -> parse_rules rules reversed rest)

let value_option = function
  | "--config" | "--project" | "--jsx-runtime" | "--test-framework"
  | "--throws-runtime" | "--enable-rule" | "--disable-rule" ->
      true
  | _ -> false

let missing_value = function
  | ("--enable-rule" | "--disable-rule") as option -> Missing_rule option
  | option -> Invalid_rule (option ^ " requires a value.")

let rec extract_format format reversed = function
  | [] -> (format, Ok (List.rev reversed))
  | "--" :: rest -> (format, Ok (List.rev_append reversed ("--" :: rest)))
  | [ "--format" ] -> (format, Error Missing_format)
  | "--format" :: value :: _ when String.starts_with ~prefix:"-" value ->
      (format, Error Missing_format)
  | "--format" :: "human" :: rest -> extract_format Human reversed rest
  | "--format" :: "json" :: rest -> extract_format Json reversed rest
  | "--format" :: value :: _ -> (format, Error (Invalid_format value))
  | option :: value :: _
    when value_option option && String.starts_with ~prefix:"-" value ->
      (format, Error (missing_value option))
  | option :: value :: rest
    when value_option option && not (String.starts_with ~prefix:"-" value) ->
      extract_format format (value :: option :: reversed) rest
  | argument :: rest -> extract_format format (argument :: reversed) rest

let parse_with_format arguments =
  let format, arguments = extract_format Human [] arguments in
  let command =
    Result.bind arguments (fun arguments ->
        parse_rules Rule_config.default [] arguments)
  in
  let command =
    Result.bind command (fun command ->
        match (format, command) with
        | Json, (Help | Version | List_rules | Language_server _) ->
            Error Unsupported_format_mode
        | _ -> Ok command)
  in
  (format, command)

let parse arguments = snd (parse_with_format arguments)

let error_message = function
  | Missing_files -> "No input files. Use --help for usage."
  | Unknown_option option -> Printf.sprintf "Unknown option: %s" option
  | Invalid_lsp_arguments -> "Usage: rescript-lint lsp --stdio"
  | Invalid_rule message -> message
  | Missing_rule option -> option ^ " requires a rule ID."
  | Missing_format -> "--format requires human or json."
  | Invalid_format value -> "Unsupported output format: " ^ value
  | Unsupported_format_mode ->
      "JSON output is supported only for lint, fix, and watch commands."
