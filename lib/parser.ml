type t =
  | Implementation of Parsetree.structure
  | Interface of Parsetree.signature

let diagnostic ~source filename error =
  Diagnostic.
    {
      filename;
      rule = "syntax";
      fixes = [];
      message = Res_diagnostics.explain error;
      range =
        Source_range.of_positions ~source
          (Res_diagnostics.get_start_pos error)
          (Res_diagnostics.get_end_pos error);
    }

let checked wrap (parsed : (_, _) Res_driver.parse_result) =
  match
    List.map
      (diagnostic ~source:parsed.source parsed.filename)
      parsed.diagnostics
    |> Source_range.sort
  with
  | first :: rest -> Error (Lint_error.Parse_errors (first, rest))
  | [] -> Ok (wrap parsed.parsetree)

type document = { tree : t; comments : Res_comment.t list }

let document wrap parsed =
  Result.map
    (fun tree -> { tree; comments = parsed.Res_driver.comments })
    (checked wrap parsed)

let parse_document (source : Source.t) =
  match source.kind with
  | Implementation ->
      Res_driver.parse_implementation_from_source ~for_printer:true
        ~display_filename:source.filename ~source:source.text
      |> document (fun tree -> Implementation tree)
  | Interface ->
      Res_driver.parse_interface_from_source ~for_printer:true
        ~display_filename:source.filename ~source:source.text
      |> document (fun tree -> Interface tree)

let parse source =
  Result.map (fun parsed -> parsed.tree) (parse_document source)

let format source =
  Result.map
    (fun { tree; comments } ->
      match tree with
      | Implementation tree -> Res_printer.print_implementation tree ~comments
      | Interface tree -> Res_printer.print_interface tree ~comments)
    (parse_document source)
