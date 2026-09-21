type declaration = { path : string list; location : Location.t }

val pattern_names : Parsetree.pattern -> string list
val declarations : Parser.t -> declaration list
val public : Project_files.t -> Project_files.unit_ -> declaration list
