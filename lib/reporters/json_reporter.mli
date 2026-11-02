val render : Report.t -> Report.response
(** One compact schema-version-1 JSON record in stdout; stderr is empty.
    Diagnostics include [documentationUrl], null for unregistered codes. *)
