type rule = { id : string; message : string list -> string option }

val check : rules:rule list -> source:Source.t -> Parser.t -> Diagnostic.t list
(** Checks qualified value references with lexical module-shadow tracking. Each
    matching rule reports at the reference; findings are in source order. *)
