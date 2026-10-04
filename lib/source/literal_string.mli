type t

val decode : string -> t option
(** Decode raw ordinary-string contents from the printer AST. Unsupported
    escapes or invalid Unicode return [None]. Templates and character literals
    must not be passed to this function. *)

val equal : t -> t -> bool

val compare : t -> t -> int
(** JavaScript UTF-16 code-unit ordering, without Unicode normalization. *)
