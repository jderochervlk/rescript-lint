let run checks =
  List.iter
    (fun (name, result) ->
      match result with
      | Ok () -> Printf.printf "ok %s\n" name
      | Error detail ->
          Printf.eprintf "FAIL %s: %s\n" name detail;
          exit 1)
    checks

let of_bools checks =
  List.map
    (fun (name, passed) ->
      (name, if passed then Ok () else Error "check failed"))
    checks
