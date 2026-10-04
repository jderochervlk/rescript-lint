type platform = Posix | Windows

val native : platform

val contains : platform:platform -> root:string -> string -> bool
(** Compare resolved paths at directory boundaries. Windows comparisons accept
    both separators; callers resolve symlinks and dots. *)
