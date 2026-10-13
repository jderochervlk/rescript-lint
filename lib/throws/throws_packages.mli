type prepared
(** Fully validated dependency exports for one package graph and initial scope.
    Rebuild on package, namespace, project-module, or imported-scope changes. *)

val prepare :
  initial:Throws_scope.t ->
  project_modules:string list ->
  Dependency_packages.t ->
  (prepared, Lint_error.t) result

val exported_scope : prepared -> Throws_scope.t

val scope :
  initial:Throws_scope.t ->
  project_modules:string list ->
  Dependency_packages.t ->
  (Throws_scope.t, Lint_error.t) result
(** Build isolated exception-contract scopes from parsed dependency packages.
    Validate public module-root collisions and exception-contract cycles. *)
