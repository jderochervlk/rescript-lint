type t
type stats = { parsed : int; reused : int; overlays : int }

type outcome = {
  cache : t;
  project : (Project_files.t, Lint_error.t) result;
  stats : stats;
}

val empty : t

val create : parse:(Source.t -> (Parser.t, Lint_error.t) result) -> t
(** An immutable cache with a fixed parser capability. *)

val load :
  ?overlay:Source.t -> root:string -> excluded:string list -> t -> outcome
(** Always rediscovers files and rereads disk sources; matching source contents,
    kinds, and filenames reuse parses regardless of timestamps. Overlay results
    never enter the disk cache. Disk/discovery failures clear entries; overlay
    parse failures preserve independent disk entries. Statistics are per load.
    Signatures and semantic analyses are not cached. *)
