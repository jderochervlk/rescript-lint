val scope : Throws_scope.t
(** Opt-in ReScript 12.3.1 runtime adapter. Public exports without an explicit
    adapted contract are unannotated, not proven nonthrowing. *)

val annotated_paths : string list list
(** Public access paths for the nine explicitly adapted JSON externals. *)
