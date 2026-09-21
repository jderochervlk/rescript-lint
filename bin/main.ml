let print_response response =
  List.iter print_endline response.Rescript_linter.Application.stdout;
  List.iter prerr_endline response.stderr;
  flush stdout;
  flush stderr

let lint_session () =
  let open Rescript_linter in
  let cache = ref Project_index.empty in
  let load_project ~config ~source =
    let next, project = Project_context.load_cached !cache ~config ~source in
    cache := next;
    project
  in
  Linter.lint_source_with_loader ~load_project

let run_once ~lint arguments =
  let response =
    Rescript_linter.Application.run
      ~lint:(fun rules filename ->
        Result.bind (Rescript_linter.Source.read filename) (lint rules))
      ~fix:(fun rules ->
        Rescript_linter.Fixer.fix_file_with_lint ~lint:(lint rules))
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

let watch ~lint files fix arguments =
  let open Rescript_linter in
  let reason = ref Running in
  let handlers = install_stop_handlers reason in
  let snapshot () = Watch.command_snapshot arguments in
  let before_run = snapshot () in
  ignore (run_once ~lint arguments);
  let initial = if fix then snapshot () else before_run in
  let dependencies = Watch.{ snapshot; wait = (fun () -> Unix.sleepf 0.2) } in
  let on_change () =
    prerr_endline "Change detected. Re-running lint.";
    ignore (run_once ~lint arguments)
  in
  Printf.eprintf "Watching %d file(s). Press Ctrl+C to stop.\n%!"
    (List.length files);
  Watch.loop_dynamic ~dependencies
    ~continue:(fun () -> !reason = Running)
    ~on_change ~refresh_after_change:fix ~initial;
  restore_stop_handlers handlers;
  stop_exit_code !reason

let main arguments =
  let lint = lint_session () in
  match Rescript_linter.Command.parse arguments with
  | Ok (Language_server rules) ->
      Rescript_linter.Lsp_runtime.run
        ~dependencies:{ lint = lint rules }
        { input = stdin; output = stdout; error = stderr }
  | Ok (Watch { files; fix; rules }) -> (
      match Rescript_linter.Inputs.files rules files with
      | Ok files -> watch ~lint files fix arguments
      | Error _ -> watch ~lint files fix arguments)
  | _ -> run_once ~lint arguments

let arguments () =
  Array.to_list Sys.argv |> List.filteri (fun index _argument -> index > 0)

let () = arguments () |> main |> exit
