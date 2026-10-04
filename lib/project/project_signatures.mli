val of_structure :
  context:Semantic_model.context -> Parsetree.structure -> Parsetree.signature

type origins = {
  values : (string list * Semantic_model.provenance) list;
  types : (string list * Semantic_model.type_origin) list;
}

val of_structure_with_declaration_origins :
  context:Semantic_model.context ->
  Parsetree.structure ->
  Parsetree.signature * origins

val of_structure_with_origins :
  context:Semantic_model.context ->
  Parsetree.structure ->
  Parsetree.signature * (string list * Semantic_model.provenance) list
(** Preserve inferred value origins separately from public signature locations.
*)
