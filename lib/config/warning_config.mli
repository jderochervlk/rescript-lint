val decode : Yojson.Basic.t -> (Policy_rules.warning_policy, string) result
(** Decode a complete warning-comment policy. Omitted fields use defaults. *)
