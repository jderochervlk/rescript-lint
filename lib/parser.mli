type t =
  | Implementation of Parsetree.structure
  | Interface of Parsetree.signature

val parse : Source.t -> (t, Lint_error.t) result
