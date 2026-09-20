type t =
  | Implementation of Parsetree.structure
  | Interface of Parsetree.signature

let diagnostic ~source filename error =
  Diagnostic.
    {
      filename;
      rule = "syntax";
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

let parse (source : Source.t) =
  match source.kind with
  | Implementation ->
      Res_driver.parse_implementation_from_source ~for_printer:true
        ~display_filename:source.filename ~source:source.text
      |> checked (fun tree -> Implementation tree)
  | Interface ->
      Res_driver.parse_interface_from_source ~for_printer:true
        ~display_filename:source.filename ~source:source.text
      |> checked (fun tree -> Interface tree)
