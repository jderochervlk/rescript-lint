let metadata =
  Rule_metadata.
    { id = "max-lines"; category = Pedantic; enabled_by_default = false }

open Syntax_policy_support

let inspect ~maximum emit (source : Source.t) =
  let lines = line_count source.text in
  if lines > maximum then
    emit "max-lines"
      (Printf.sprintf
         "This file has %d physical lines; the configured maximum is %d." lines
         maximum)
      file_start
