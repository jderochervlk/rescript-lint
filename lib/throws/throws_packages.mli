val scope :
  initial:Throws_scope.t ->
  project_modules:string list ->
  Dependency_packages.t ->
  (Throws_scope.t, Lint_error.t) result
(** Build isolated exception-contract scopes from parsed dependency packages.
    Validate public module-root collisions and exception-contract cycles. *)
