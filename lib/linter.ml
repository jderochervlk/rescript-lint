let rules = [ No_console.rule; No_object_magic.rule; No_unsafe.rule ]

let lint_source (source : Source.t) =
  Result.bind (Parser.parse source) (fun tree ->
      Result.map
        (fun throws ->
          Source_range.sort
            (Banned_api.check ~rules ~source tree
            @ Rules_of_hooks.check ~source tree
            @ throws))
        (No_unhandled_throws.check ~source tree))

let lint_file filename = Result.bind (Source.read filename) lint_source
