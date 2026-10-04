type error = Unsupported_scheme of { uri : string }

let local_path uri =
  let rendered = Lsp.Types.DocumentUri.to_string uri in
  if String.starts_with ~prefix:"file:" rendered then
    Ok (Lsp.Types.DocumentUri.to_path uri)
  else Error (Unsupported_scheme { uri = rendered })

let render_error = function
  | Unsupported_scheme { uri } ->
      Printf.sprintf "Only file URIs are supported: %s" uri
