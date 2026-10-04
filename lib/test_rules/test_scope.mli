type registration_kind = Test | Describe

type registration = {
  kind : registration_kind;
  title_index : int;
  todo : bool;
  focused : bool;
}

type hook = Before_all | Before_each | After_each | After_all

type value =
  | Unknown
  | Registration of registration
  | Hook of hook
  | Assertion
  | Skip
  | Skip_if
  | Function of Parsetree.expression * t

and t

val empty : t
val unknown : t
val initial : t
val with_module_signatures : (string * Parsetree.signature) list -> t
val overlay : t -> t -> t
val add_value : string -> value -> t -> t
val add_module : string -> t -> t -> t
val module_path : t -> Longident.t -> t option
val expression : t -> Parsetree.expression -> value
val bind_pattern : value -> Parsetree.pattern -> t -> t
val bindings : t -> Asttypes.rec_flag -> Parsetree.value_binding list -> t * t
val external_value : Parsetree.value_description -> value
val constrain : t -> Parsetree.module_type -> t
val unwrap : Parsetree.expression -> Parsetree.expression
