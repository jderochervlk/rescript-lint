type limits = {
  max_nesting : int;
  max_params : int;
  max_lines_per_function : int;
}

val default_limits : limits

val check :
  ?limits:limits -> source:Source.t -> Parser.document -> Diagnostic.t list
