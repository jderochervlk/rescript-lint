type t =
  | Implementation of Parsetree.structure
  | Interface of Parsetree.signature

val parse : Source.t -> (t, Lint_error.t) result

type document = { tree : t; comments : Res_comment.t list }

val parse_document : Source.t -> (document, Lint_error.t) result
val format : Source.t -> (string, Lint_error.t) result

type parsed_overlay = private { source : Source.t; document : document }

val parse_overlay : Source.t -> (parsed_overlay, Lint_error.t) result
(** Pair the authoritative source with its validated tree and comments. *)
