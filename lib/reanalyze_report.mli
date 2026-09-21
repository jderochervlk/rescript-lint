type item = {
  filename : string;
  start_line : int;
  start_column : int;
  message : string;
}

val decode : Yojson.Basic.t -> (item list, string) result

val check :
  project:Project_files.t ->
  report:string ->
  source:Source.t ->
  (Diagnostic.t list, string) result
