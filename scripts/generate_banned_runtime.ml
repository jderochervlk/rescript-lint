open Rescript_linter

let write filename contents =
  try
    let channel = open_out_bin filename in
    Fun.protect
      ~finally:(fun () -> close_out channel)
      (fun () -> output_string channel contents);
    Ok ()
  with Sys_error detail -> Error (Lint_error.Write_error { filename; detail })

let run = function
  | [ _; directory; output ] ->
      Result.bind (Runtime_exports.read ~directory) (fun entries ->
          write output (Runtime_exports.render entries))
  | _ ->
      Error
        (Lint_error.Write_error
           {
             filename = "generate_banned_runtime";
             detail =
               "Usage: generate_banned_runtime RUNTIME_DIRECTORY OUTPUT_FILE";
           })

let () =
  match run (Array.to_list Sys.argv) with
  | Ok () -> ()
  | Error error ->
      prerr_endline (Lint_error.render error);
      exit 1
