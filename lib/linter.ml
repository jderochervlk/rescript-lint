let lint_source (source : Source.t) =
  Result.map (No_console.check ~source) (Parser.parse source)

let lint_file filename = Result.bind (Source.read filename) lint_source
