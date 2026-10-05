val initial_scope : Semantic_model.context -> Semantic_model.scope
(** Initialize runtime bindings and standard types, then overlay project modules
    and resolve their public signatures. *)
