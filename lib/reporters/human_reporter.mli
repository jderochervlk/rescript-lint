val render : Report.t -> Report.response
(** Findings go to stdout; failures go to stderr, in their input order.
    Registered-rule diagnostics include a GitHub documentation continuation. *)
