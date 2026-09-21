val modules : project_modules:string list -> Parser.t -> string list
(** Sorted project roots referenced by the tree, respecting local module scopes.
    Non-throws attribute payloads do not create dependencies. *)
