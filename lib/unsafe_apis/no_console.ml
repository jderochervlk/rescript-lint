let family arity name =
  name :: (name ^ "Many")
  :: List.init (arity - 1) (fun index -> name ^ string_of_int (index + 2))

let modern_members =
  [
    "assert_";
    "assert2";
    "assert3";
    "assert4";
    "assert5";
    "assert6";
    "assertMany";
    "clear";
    "count";
    "countReset";
    "dir";
    "dirxml";
    "group";
    "groupCollapsed";
    "groupEnd";
    "table";
    "time";
    "timeEnd";
    "timeLog";
    "trace";
  ]
  @ List.concat_map (family 6) [ "debug"; "error"; "info"; "log"; "warn" ]

let legacy_members =
  [ "trace"; "timeStart"; "timeEnd"; "table" ]
  @ List.concat_map (family 4) [ "error"; "info"; "log"; "warn" ]

let is_console = function
  | [ "Console"; member ]
  | [ "Stdlib"; "Console"; member ]
  | [ "Stdlib_Console"; member ] ->
      List.mem member modern_members
  | [ "Js"; "Console"; member ] | [ "Js_console"; member ] ->
      List.mem member legacy_members
  | [ "Js"; member ] -> List.mem member (family 4 "log")
  | _ -> false

let message names =
  if is_console names then Some ("Do not use " ^ String.concat "." names ^ ".")
  else None

let rule = Banned_api.{ id = "no-console"; message }
