(* Read compiler metadata rather than guessing Dune's object-file names. This
   also discovers test executables omitted by Dune 3.24's workspace description. *)
let rec artifacts directory =
  Sys.readdir directory |> Array.to_list |> List.sort String.compare
  |> List.concat_map (fun name ->
      let path = Filename.concat directory name in
      if Sys.is_directory path then artifacts path
      else if
        Filename.check_suffix path ".cmt" || Filename.check_suffix path ".cmti"
      then [ path ]
      else [])

let describe path =
  let info = Cmt_format.read_cmt path in
  match (info.cmt_sourcefile, info.cmt_annots) with
  | Some source, (Cmt_format.Implementation _ | Interface _) ->
      Some
        (`Assoc
           [
             ("source", `String source);
             ("artifact", `String path);
             ( "fresh",
               `Bool
                 (Sys.file_exists source
                 && info.cmt_source_digest = Some (Digest.BLAKE128.file source)
                 ) );
           ])
  | _ -> None

let () =
  Array.to_list Sys.argv |> List.tl |> List.concat_map artifacts
  |> List.filter_map describe
  |> fun entries ->
  Yojson.Basic.to_channel stdout (`List entries);
  output_char stdout '\n'
