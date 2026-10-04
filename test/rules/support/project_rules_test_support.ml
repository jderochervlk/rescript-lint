open Rescript_linter

let source filename text = Source.{ filename; text; kind = Implementation }

let enabled id options =
  Rule_config.set
    (Rule_config.with_options options Rule_config.default)
    ~id ~enabled:true

let check id options source predicate =
  match enabled id options with
  | Error _ -> false
  | Ok config -> (
      match Linter.lint_source_with_rules config source with
      | Error _ -> false
      | Ok findings ->
          predicate
            (List.filter
               (fun (finding : Diagnostic.t) -> finding.rule = id)
               findings))

let found = function _ :: _ -> true | [] -> false
let clean = function [] -> true | _ -> false

let write filename text =
  Out_channel.with_open_bin filename (fun channel -> output_string channel text)

let setup root =
  Unix.mkdir (Filename.concat root "src") 0o700;
  write
    (Filename.concat root "rescript.json")
    "{\"sources\":[{\"dir\":\"src\",\"subdirs\":true}]}";
  write
    (Filename.concat root "src/Api.res")
    "let old = x => x\n\
     let hidden = 1\n\
     type public = int\n\
     type hiddenType = string\n";
  write
    (Filename.concat root "src/Api.resi")
    "@deprecated(\"Use modern\")\nlet old: int => int\ntype public = int\n";
  write (Filename.concat root "src/Main.res") "let value = Api.old(1)\n";
  Unix.mkdir (Filename.concat root "src/generated") 0o700;
  write (Filename.concat root "src/generated/Generated.res") "let value = 0\n"

let rec remove directory =
  Sys.readdir directory
  |> Array.iter (fun name ->
      let path = Filename.concat directory name in
      if (Unix.lstat path).st_kind = Unix.S_DIR then remove path
      else Sys.remove path);
  Unix.rmdir directory

let with_project run =
  let root = Filename.temp_file "rescript-project-" "" in
  Sys.remove root;
  Unix.mkdir root 0o700;
  let root = Unix.realpath root in
  Fun.protect
    ~finally:(fun () -> remove root)
    (fun () ->
      setup root;
      run root)
