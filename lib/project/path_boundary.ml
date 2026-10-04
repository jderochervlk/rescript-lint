type platform = Posix | Windows

let native = if Sys.win32 then Windows else Posix

let normalize platform path =
  match platform with
  | Posix -> path
  | Windows ->
      String.map (function '/' -> '\\' | character -> character) path
      |> String.lowercase_ascii

let contains ~platform ~root path =
  let root = normalize platform root in
  let path = normalize platform path in
  let separator = match platform with Posix -> "/" | Windows -> "\\" in
  let prefix =
    if String.ends_with ~suffix:separator root then root else root ^ separator
  in
  root <> "" && (path = root || String.starts_with ~prefix path)
