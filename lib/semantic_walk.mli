type callbacks = {
  expression : Semantic_model.scope -> Parsetree.expression -> unit;
  bound_value : Semantic_model.value -> Semantic_model.value;
  bindings :
    Semantic_model.scope ->
    Asttypes.rec_flag ->
    Parsetree.value_binding list ->
    unit;
  structure_item : Semantic_model.scope -> Parsetree.structure_item -> unit;
  module_reference : Semantic_model.scope -> Longident.t Location.loc -> unit;
  core_type : Semantic_model.scope -> Parsetree.core_type -> unit;
  initialization : Semantic_model.scope -> Parsetree.structure_item -> unit;
}

val nothing : callbacks

val expression :
  callbacks -> Semantic_model.scope -> Parsetree.expression -> unit

val structure :
  callbacks ->
  Semantic_model.scope ->
  Parsetree.structure ->
  Semantic_model.scope

val iter : callbacks -> Semantic_model.scope -> Parser.t -> unit
