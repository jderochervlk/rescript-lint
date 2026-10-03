let () =
  print_endline
    (Yojson.Basic.pretty_to_string Rescript_linter.Config_schema.document)
