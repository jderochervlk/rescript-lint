type watch = { files : string list; fix : bool }

type t =
  | Help
  | Version
  | Lint of string list
  | Fix of string list
  | Watch of watch
  | Language_server

type error = Missing_files | Unknown_option of string | Invalid_lsp_arguments

let version = "0.1.0-beta.1"

let help =
  "Usage: rescript-lint [--fix] [--watch] [--] FILE.res [FILE.resi ...]\n\
  \       rescript-lint lsp --stdio\n\n\
   Options:\n\
  \  -h, --help     Show this help\n\
  \  --version      Show the version\n\
  \  --fix          Apply safe fixes, then report remaining errors\n\
  \  -w, --watch    Re-run when an input file changes\n\
  \  --             Treat remaining arguments as file paths\n"

let files_command ~fix ~watch = function
  | [] -> Error Missing_files
  | files when watch -> Ok (Watch { files; fix })
  | files -> Ok (if fix then Fix files else Lint files)

let rec parse_files fix watch reversed = function
  | [] -> files_command ~fix ~watch (List.rev reversed)
  | "--" :: rest -> files_command ~fix ~watch (List.rev_append reversed rest)
  | "--fix" :: rest -> parse_files true watch reversed rest
  | ("--watch" | "-w") :: rest -> parse_files fix true reversed rest
  | argument :: _ when String.starts_with ~prefix:"-" argument ->
      Error (Unknown_option argument)
  | file :: rest -> parse_files fix watch (file :: reversed) rest

let parse = function
  | [ "--help" ] | [ "-h" ] -> Ok Help
  | [ "--version" ] -> Ok Version
  | [ "lsp"; "--stdio" ] -> Ok Language_server
  | "lsp" :: _ -> Error Invalid_lsp_arguments
  | arguments -> parse_files false false [] arguments

let error_message = function
  | Missing_files -> "No input files. Use --help for usage."
  | Unknown_option option -> Printf.sprintf "Unknown option: %s" option
  | Invalid_lsp_arguments -> "Usage: rescript-lint lsp --stdio"
