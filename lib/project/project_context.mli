val load :
  config:Rule_config.t ->
  overlay:Parser.parsed_overlay ->
  (Project_files.t option, Lint_error.t) result

val load_cached :
  Project_index.t ->
  config:Rule_config.t ->
  overlay:Parser.parsed_overlay ->
  Project_index.t * (Project_files.t option, Lint_error.t) result

type prepared
(** Immutable declaration metadata for one parsed project snapshot. Rebuild
    after overlays, project files, or dependency configuration change. No
    semantic cache or automatic invalidation is provided. *)

val prepare : Project_files.t option -> prepared
(** Infer project signatures and module names, preserving interface precedence.
*)

val prepare_with_dependencies :
  config:Rule_config.t ->
  Project_files.t option ->
  (prepared, Lint_error.t) result
(** Prepare explicitly configured dependency declarations when provenance
    analysis is enabled. Errors retain their provider context; the public
    semantic wrapper attaches the caller's source-root-analysis diagnostic.
    Reuse only with the same dependency options and provenance activation. *)

val context :
  config:Rule_config.t -> source:Source.t -> prepared -> Semantic_model.context
(** Derive enabled rules, entry-module status, and thresholds from resolved
    per-file configuration without rebuilding declaration metadata. *)

val semantic :
  config:Rule_config.t ->
  source:Source.t ->
  Project_files.t option ->
  Semantic_model.context

val semantic_with_dependencies :
  config:Rule_config.t ->
  source:Source.t ->
  Project_files.t option ->
  (Semantic_model.context, Lint_error.t) result
(** Extend project source metadata with explicitly configured dependency
    packages only while declaration-provenance analysis is active. *)
