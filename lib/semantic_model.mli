module Names : Map.S with type key = string

type typ =
  | Unknown
  | Unit
  | Bool
  | Int
  | Float
  | String
  | Array of typ
  | List of typ
  | Option of typ
  | Result of typ
  | Promise of typ
  | Tuple of typ list
  | Record of (string * typ * bool) list
  | Variant of bool
  | Regexp
  | Function of (Asttypes.arg_label * typ) list * typ

type value = {
  identity : string;
  typ : typ;
  api : string list option;
  pure : bool;
  expression : Parsetree.expression option;
  attributes : Parsetree.attributes;
  canonical : string list option;
}

type type_origin = Standard of string list | Declared of string list option

type scope = {
  values : value Names.t;
  modules : scope Names.t;
  types : typ Names.t;
  type_identities : type_origin Names.t;
  constructors : typ Names.t;
  origin : string list option;
  opaque : bool;
}

type context = {
  module_signatures : (string * Parsetree.signature) list;
  project_modules : string list;
  entry_module : bool;
  deep_equality_threshold : int;
  enabled : string list;
}

val default_context : context
val unknown_value : Location.t -> value
val identity : Location.t -> string
val empty : scope
val unknown : scope
val initial : context -> scope
val add_value : string -> value -> scope -> scope
val add_module : string -> scope -> scope -> scope
val overlay : scope -> scope -> scope
val path : Longident.t -> string list option
val module_path : scope -> string list -> scope option
val module_identity : scope -> Longident.t -> string list option
val type_identity : scope -> Longident.t -> string list option
val standard_type : scope -> Longident.t -> string list option
val resolve : scope -> Longident.t -> value option
val open_path : scope -> Longident.t -> scope
val unwrap : Parsetree.expression -> Parsetree.expression
val type_of : scope -> Parsetree.core_type -> typ
val infer : scope -> Parsetree.expression -> typ

val application :
  scope ->
  Parsetree.expression ->
  (Parsetree.expression * (Asttypes.arg_label * Parsetree.expression) list)
  option

val bind_pattern : scope -> typ -> Parsetree.pattern -> scope
val pattern_name : Parsetree.pattern -> string option
val pattern_type : scope -> Parsetree.pattern -> typ

val function_parts :
  Parsetree.expression ->
  (Asttypes.arg_label * Parsetree.pattern) list * Parsetree.expression

val has_attribute : string -> Parsetree.attributes -> bool
val pure : scope -> Parsetree.expression -> bool
val callable_pure : scope -> Parsetree.expression -> bool
val stable : scope -> Parsetree.expression -> bool
val bind_value : scope -> Parsetree.value_binding -> scope
val add_declaration : scope -> Parsetree.type_declaration -> scope
val add_external : scope -> Parsetree.value_description -> scope
val signature : ?prefix:string list -> scope -> Parsetree.signature -> scope
