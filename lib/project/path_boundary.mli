type platform = Posix | Windows

val native : platform

val resolve : string -> string
(** Resolve filesystem casing, symlinks and dots. Missing paths retain their
    suffix beneath the nearest existing ancestor; other lookup failures retain
    the original spelling. *)

val contains : platform:platform -> root:string -> string -> bool
(** Compare resolved paths at directory boundaries. Windows comparisons accept
    both separators and ignore ASCII case; callers resolve symlinks and dots. *)
