val rule_ids : string list

type limits = {
  max_nesting : int;
  max_params : int;
  max_lines_per_function : int;
}

val default_limits : limits

type comment_context = Line | Block | Documentation
type warning_policy

val default_warning_terms : string list
val default_warning_policy : warning_policy
val warning_terms_config : warning_policy -> string list
val warning_contexts_config : warning_policy -> comment_context list

val warning_policy :
  terms:string list ->
  allowed_contexts:comment_context list ->
  (warning_policy, string) result
(** Terms are nonempty, unique ASCII identifiers starting with a letter, matched
    case-insensitively. Allowed contexts exempt whole parsed comments. *)

val check :
  ?limits:limits ->
  ?warning_policy:warning_policy ->
  source:Source.t ->
  Parser.document ->
  Diagnostic.t list
