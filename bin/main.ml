let main arguments =
  let response =
    Rescript_linter.Application.run ~lint:Rescript_linter.Linter.lint_file
      ~fix:Rescript_linter.Fixer.fix_file arguments
  in
  List.iter print_endline response.stdout;
  List.iter prerr_endline response.stderr;
  Rescript_linter.Application.exit_code response.outcome

let arguments () =
  Array.to_list Sys.argv |> List.filteri (fun index _argument -> index > 0)

let () = arguments () |> main |> exit
