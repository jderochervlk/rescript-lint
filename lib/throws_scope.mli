type exception_ref = { identity : string; display : string }
type contract = Any | Named of exception_ref list
type callable = Plain | Annotated of contract
type error = Unresolved_exception of string list
type t

val empty : t
val unknown : t
val is_opaque : t -> bool
val initial : t
val overlay : t -> t -> t
val value : t -> string list -> callable option
val exception_id : t -> string list -> string option
val module_scope : t -> string list -> t option
val module_type : t -> string list -> t option
val add_value : string -> callable -> t -> t
val add_module : string -> t -> t -> t
val add_module_type : string -> t -> t -> t
val bind_pattern : callable -> Parsetree.pattern -> t -> t

val bind_exception :
  filename:string -> Parsetree.extension_constructor -> t -> t

val exception_export :
  filename:string -> t -> Parsetree.extension_constructor -> t

val shadow_types : Parsetree.type_declaration list -> t -> t
val resolve : t -> Throws_annotation.t -> (contract, error) result
val exception_bindings : t -> (string list * string) list
val with_exception_aliases : (string * string) list -> t -> t
val exception_aliases : t -> (string * string) list
