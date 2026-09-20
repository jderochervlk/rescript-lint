type t = Help | Version | Lint of string list | Fix of string list
type error = Missing_files | Unknown_option of string

let version = "0.1.0-beta.1"

let help =
  "Usage: rescript-lint [--fix] [--] FILE.res [FILE.resi ...]\n\n\
   Options:\n\
  \  -h, --help     Show this help\n\
  \  --version      Show the version\n\
  \  --fix          Apply safe fixes, then report remaining errors\n\
  \  --             Treat remaining arguments as file paths\n"

let files_command ~fix = function
  | [] -> Error Missing_files
  | files -> Ok (if fix then Fix files else Lint files)

let rec parse_files fix reversed = function
  | [] -> files_command ~fix (List.rev reversed)
  | "--" :: rest -> files_command ~fix (List.rev_append reversed rest)
  | "--fix" :: rest -> parse_files true reversed rest
  | argument :: _ when String.starts_with ~prefix:"-" argument ->
      Error (Unknown_option argument)
  | file :: rest -> parse_files fix (file :: reversed) rest

let parse = function
  | [ "--help" ] | [ "-h" ] -> Ok Help
  | [ "--version" ] -> Ok Version
  | arguments -> parse_files false [] arguments

let error_message = function
  | Missing_files -> "No input files. Use --help for usage."
  | Unknown_option option -> Printf.sprintf "Unknown option: %s" option
