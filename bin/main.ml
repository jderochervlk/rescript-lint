let print_response response =
  List.iter print_endline response.Rescript_linter.Application.stdout;
  List.iter prerr_endline response.stderr;
  flush stdout;
  flush stderr

let run_once arguments =
  let response =
    Rescript_linter.Application.run
      ~lint:Rescript_linter.Linter.lint_file_with_rules
      ~fix:(fun rules ->
        Rescript_linter.Fixer.fix_file_with_lint
          ~lint:(Rescript_linter.Linter.lint_source_with_rules rules))
      arguments
  in
  print_response response;
  Rescript_linter.Application.exit_code response.outcome

type stop_reason = Running | Interrupted | Terminated

let stop_exit_code = function
  | Running -> 0
  | Interrupted -> 130
  | Terminated -> 143

let install_stop_handlers reason =
  let handler stopped = Sys.Signal_handle (fun _signal -> reason := stopped) in
  let interrupt = Sys.signal Sys.sigint (handler Interrupted) in
  let terminate = Sys.signal Sys.sigterm (handler Terminated) in
  (interrupt, terminate)

let restore_stop_handlers (interrupt, terminate) =
  Sys.set_signal Sys.sigint interrupt;
  Sys.set_signal Sys.sigterm terminate

let watch files fix arguments =
  let open Rescript_linter in
  let reason = ref Running in
  let handlers = install_stop_handlers reason in
  let before_run = Watch.observe files in
  ignore (run_once arguments);
  let initial = if fix then Watch.observe files else before_run in
  let dependencies = Watch.{ observe; sleep = (fun () -> Unix.sleepf 0.2) } in
  let on_change () =
    prerr_endline "Change detected. Re-running lint.";
    ignore (run_once arguments)
  in
  Printf.eprintf "Watching %d file(s). Press Ctrl+C to stop.\n%!"
    (List.length files);
  Watch.loop ~dependencies
    ~continue:(fun () -> !reason = Running)
    ~on_change ~refresh_after_change:fix ~files ~initial;
  restore_stop_handlers handlers;
  stop_exit_code !reason

let main arguments =
  match Rescript_linter.Command.parse arguments with
  | Ok (Language_server rules) ->
      Rescript_linter.Lsp_runtime.run
        ~dependencies:
          { lint = Rescript_linter.Linter.lint_source_with_rules rules }
        { input = stdin; output = stdout; error = stderr }
  | Ok (Watch { files; fix; rules }) -> (
      match Rescript_linter.Inputs.files rules files with
      | Ok files -> watch files fix arguments
      | Error _ -> run_once arguments)
  | _ -> run_once arguments

let arguments () =
  Array.to_list Sys.argv |> List.filteri (fun index _argument -> index > 0)

let () = arguments () |> main |> exit
