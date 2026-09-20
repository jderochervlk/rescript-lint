type t = { loc : Location.t; before : bool; after : bool }

val structure : Parsetree.structure_item -> t
val signature : Parsetree.signature_item -> t
val expression : Parsetree.expression -> t
val first : Parsetree.expression -> t
val bindings : Parsetree.value_binding list -> t
