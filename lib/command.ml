type t = Help | Version | Lint of string list
type error = Missing_files | Unknown_option of string

let version = "0.1.0-dev"

let help =
  "Usage: rescript-lint [--] FILE.res [FILE.resi ...]\n\n\
   Options:\n\
  \  -h, --help     Show this help\n\
  \  --version      Show the version\n\
  \  --             Treat remaining arguments as file paths\n"

let files_command = function
  | [] -> Error Missing_files
  | files -> Ok (Lint files)

let rec parse_files reversed = function
  | [] -> files_command (List.rev reversed)
  | "--" :: rest -> files_command (List.rev_append reversed rest)
  | argument :: _ when String.starts_with ~prefix:"-" argument ->
      Error (Unknown_option argument)
  | file :: rest -> parse_files (file :: reversed) rest

let parse = function
  | [ "--help" ] | [ "-h" ] -> Ok Help
  | [ "--version" ] -> Ok Version
  | arguments -> parse_files [] arguments

let error_message = function
  | Missing_files -> "No input files. Use --help for usage."
  | Unknown_option option -> Printf.sprintf "Unknown option: %s" option
