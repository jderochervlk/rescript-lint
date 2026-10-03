type item = {
  filename : string;
  start_line : int;
  start_column : int;
  message : string;
}

let item = function
  | `Assoc fields -> (
      match List.assoc_opt "name" fields with
      | Some
          (`String
             ("Warning Dead Value" | "Warning Dead Value With Side Effects"))
        -> (
          match
            ( List.assoc_opt "file" fields,
              List.assoc_opt "range" fields,
              List.assoc_opt "message" fields )
          with
          | ( Some (`String filename),
              Some
                (`List
                   [
                     `Int start_line;
                     `Int start_column;
                     `Int finish_line;
                     `Int finish_column;
                   ]),
              Some (`String message) )
            when start_line >= 0 && start_column >= 0
                 && finish_line >= start_line && finish_column >= 0
                 && (finish_line > start_line || finish_column >= start_column)
            ->
              Ok (Some { filename; start_line; start_column; message })
          | _ -> Error "Malformed Reanalyze value diagnostic.")
      | Some (`String _) -> Ok None
      | _ -> Error "Reanalyze diagnostic has no name.")
  | _ -> Error "Expected a Reanalyze diagnostic object."

let decode = function
  | `List entries ->
      List.fold_left
        (fun result entry ->
          Result.bind result (fun items ->
              Result.map (fun item -> items @ Option.to_list item) (item entry)))
        (Ok []) entries
  | _ -> Error "Reanalyze report must be a JSON array."

let rec artifacts directory =
  Sys.readdir directory |> Array.to_list
  |> List.concat_map (fun name ->
      let filename = Filename.concat directory name in
      match (Unix.lstat filename).st_kind with
      | Unix.S_DIR -> artifacts filename
      | Unix.S_REG when List.mem (Filename.extension name) [ ".cmt"; ".cmti" ]
        ->
          [ filename ]
      | _ -> [])

let artifact_for unit filename =
  let extension =
    match unit.Project_files.source.kind with
    | Source.Implementation -> ".cmt"
    | Interface -> ".cmti"
  in
  let basename = Filename.basename filename |> Filename.remove_extension in
  Filename.extension filename = extension
  && (basename = unit.name
     || String.starts_with ~prefix:(unit.name ^ "-") basename)

let check_unit ~report_time artifacts unit =
  match Source.read unit.Project_files.source.filename with
  | Error error -> Error (Lint_error.render error)
  | Ok disk when disk.text <> unit.source.text ->
      Error
        "Unused-export analysis requires saved source matching the compiler \
         artifacts."
  | Ok _ -> (
      match List.find_opt (artifact_for unit) artifacts with
      | None ->
          Error
            ("Missing compiler artifact for " ^ unit.source.filename
           ^ ". Build the project before analyzing unused exports.")
      | Some filename ->
          let modified = (Unix.stat filename).st_mtime in
          if modified < unit.modified then
            Error ("Stale compiler artifact for " ^ unit.source.filename)
          else if report_time < modified || report_time < unit.modified then
            Error "Reanalyze report is stale; regenerate it after building."
          else Ok ())

let freshness project report =
  let files =
    [ "lib/ocaml"; "lib/bs" ]
    |> List.concat_map (fun relative ->
        let directory = Filename.concat project.Project_files.root relative in
        if Sys.file_exists directory && Sys.is_directory directory then
          artifacts directory
        else [])
  in
  let report_time = (Unix.stat report).st_mtime in
  List.fold_left
    (fun result unit ->
      Result.bind result (fun () -> check_unit ~report_time files unit))
    (Ok ()) project.units

let matching_declaration declarations item =
  List.find_opt
    (fun declaration ->
      let start = declaration.Project_exports.location.Location.loc_start in
      start.pos_lnum - 1 = item.start_line
      && start.pos_cnum - start.pos_bol = item.start_column)
    declarations

let findings ~project ~source items =
  let unit =
    List.find_opt
      (fun unit ->
        Project_files.canonical unit.Project_files.source.filename
        = Project_files.canonical source.Source.filename)
      project.Project_files.units
  in
  match unit with
  | None -> Error "The source is not in the configured project source set."
  | Some unit ->
      let declarations = Project_exports.public project unit in
      let filename = Project_files.canonical source.filename in
      Ok
        (List.filter_map
           (fun item ->
             let file =
               if Filename.is_relative item.filename then
                 Filename.concat project.root item.filename
               else item.filename
             in
             if Project_files.canonical file <> filename then None
             else
               Option.map
                 (fun declaration ->
                   Diagnostic.
                     {
                       filename = source.filename;
                       rule = "no-unused-export";
                       message = item.message;
                       help = None;
                       symbol = None;
                       fixes = [];
                       range =
                         Source_range.of_location ~source:source.text
                           declaration.Project_exports.location;
                     })
                 (matching_declaration declarations item))
           items)

let check ~project ~report ~source =
  try
    Result.bind (freshness project report) (fun () ->
        Result.bind
          (decode (Yojson.Basic.from_file report))
          (findings ~project ~source))
  with
  | Sys_error detail -> Error detail
  | Yojson.Json_error detail -> Error ("Invalid Reanalyze report: " ^ detail)
  | Unix.Unix_error (error, operation, _) ->
      Error (operation ^ ": " ^ Unix.error_message error)
