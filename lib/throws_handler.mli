type t

val empty : t
val union : t -> t -> t
val catches : Throws_scope.t -> Parsetree.case list -> t
val switches : Throws_scope.t -> Parsetree.case list -> t
val missing : t -> Throws_scope.contract -> string list
