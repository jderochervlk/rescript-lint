type error = Unsupported_scheme of { uri : string }

val local_path : Lsp.Types.DocumentUri.t -> (string, error) result
val render_error : error -> string
