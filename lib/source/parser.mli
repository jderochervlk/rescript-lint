type t =
  | Implementation of Parsetree.structure
  | Interface of Parsetree.signature

val parse : Source.t -> (t, Lint_error.t) result

type document = { tree : t; comments : Res_comment.t list }

val parse_document : Source.t -> (document, Lint_error.t) result
val format : Source.t -> (string, Lint_error.t) result
