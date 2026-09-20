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

let write_failure filename detail =
  Error (Lint_error.Write_error { filename; detail })

let unchanged original stat =
  let current = Unix.lstat original.filename in
  current.Unix.st_kind = Unix.S_REG
  && current.st_ino = stat.Unix.st_ino
  && current.st_dev = stat.st_dev
  && current.st_nlink = 1
  && read_text original.filename = Ok original.text

let replace original stat text =
  let temporary, channel =
    Filename.open_temp_file
      ~temp_dir:(Filename.dirname original.filename)
      ~mode:[ Open_binary ] ".rescript-lint-" ".tmp"
  in
  Fun.protect
    ~finally:(fun () ->
      close_out_noerr channel;
      if Sys.file_exists temporary then Sys.remove temporary)
    (fun () ->
      output_string channel text;
      flush channel;
      Unix.chmod temporary stat.Unix.st_perm;
      close_out channel;
      if unchanged original stat then (
        Unix.rename temporary original.filename;
        Ok ())
      else write_failure original.filename "File changed while applying fixes.")

let write ~original text =
  try
    let stat = Unix.lstat original.filename in
    if stat.st_kind <> Unix.S_REG || stat.st_nlink <> 1 then
      write_failure original.filename
        "Fixes require a regular file with one link; symlinks are not \
         rewritten."
    else if not (unchanged original stat) then
      write_failure original.filename "File changed since it was read."
    else if stat.st_perm land 0o222 = 0 then
      write_failure original.filename "File is read-only."
    else replace original stat text
  with
  | Sys_error detail -> write_failure original.filename detail
  | Unix.Unix_error (error, operation, _) ->
      write_failure original.filename
        (operation ^ ": " ^ Unix.error_message error)
