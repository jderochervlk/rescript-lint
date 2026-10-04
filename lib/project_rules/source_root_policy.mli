type root = { configured : string; canonical : string }
type t = root list

val load : string list -> (t, string) result
(** Resolve every configured directory through [realpath], preserving
    declaration order. Missing, unreadable, non-directory, and duplicate
    canonical roots are rejected. *)

val matching : t -> filename:string -> root option
(** Return the first root containing [filename] at a directory boundary. *)

val contains : root -> filename:string -> bool
val encode : string list -> Yojson.Basic.t
