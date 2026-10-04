val check : source:Source.t -> Parser.t -> Diagnostic.t list
(** Source-level placement checks, without symbol or full control-flow
    resolution. *)
