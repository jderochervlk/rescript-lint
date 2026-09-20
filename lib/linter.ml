let rules = [ No_console.rule; No_object_magic.rule ]

let lint_source (source : Source.t) =
  Result.map (Banned_api.check ~rules ~source) (Parser.parse source)

let lint_file filename = Result.bind (Source.read filename) lint_source
