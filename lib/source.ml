type kind = Implementation | Interface
type t = { filename : string; text : string; kind : kind }

let kind filename =
  match Filename.extension filename with
  | ".res" -> Ok Implementation
  | ".resi" -> Ok Interface
  | _ -> Error (Lint_error.Unsupported_file filename)

let read_text filename =
  try Ok (In_channel.with_open_bin filename In_channel.input_all)
  with Sys_error detail -> Error (Lint_error.Read_error { filename; detail })

let read filename =
  Result.bind (kind filename) (fun kind ->
      Result.map (fun text -> { filename; text; kind }) (read_text filename))
