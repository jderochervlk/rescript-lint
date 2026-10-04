type property = {
  name : string;
  value : Parsetree.expression option;
  optional : bool;
  location : Location.t;
}

type element = {
  name : string list;
  props : property list;
  children : Parsetree.expression list;
  spread : bool;
  fragment : bool;
  location : Location.t;
  expression : Parsetree.expression;
}

type prop_value = Missing | Unknown | Value of Parsetree.expression
type content = Empty | Present | Dynamic

val of_expression : Parsetree.expression -> element option
val intrinsic_tag : element -> string option
val prop : string -> element -> prop_value
val present : string -> element -> bool
val absent : string -> element -> bool
val string : Parsetree.expression -> string option
val integer : Parsetree.expression -> int option
val boolean : Parsetree.expression -> bool option
val string_prop : string -> element -> string option
val bool_prop : string -> element -> bool option
val int_prop : string -> element -> int option
val words : string -> string list
val children_content : element -> content
val hidden : element -> bool
val accessible_label : element -> content
val elements : Parser.t -> element list

val unshadowed_module :
  ?module_signatures:(string * Parsetree.signature) list ->
  string ->
  Parser.t ->
  bool

val static_text : react_unshadowed:bool -> Parsetree.expression -> string option
val emit : source:Source.t -> string -> string -> Location.t -> Diagnostic.t

type role = {
  role_name : string;
  required : string list;
  supported : string list;
  prohibited : string list;
  interactive : bool;
}

val roles : role list
val find_role : string -> role option
val explicit_role : element -> role option
val implicit_role : element -> string option
val native_interactive : element -> bool option
val focusable : element -> bool option
val aria_name : string -> string option
val native_tag : string -> string option
