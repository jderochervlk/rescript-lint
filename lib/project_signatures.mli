val of_structure :
  context:Semantic_model.context -> Parsetree.structure -> Parsetree.signature

val of_structure_with_origins :
  context:Semantic_model.context ->
  Parsetree.structure ->
  Parsetree.signature * (string list * Semantic_model.provenance) list
(** Preserve inferred value origins separately from public signature locations.
*)
