type category =
  | Correctness
  | Suspicious
  | Pedantic
  | Perf
  | Style
  | Restriction

type t = { id : string; category : category; enabled_by_default : bool }

let category_name = function
  | Correctness -> "correctness"
  | Suspicious -> "suspicious"
  | Pedantic -> "pedantic"
  | Perf -> "perf"
  | Style -> "style"
  | Restriction -> "restriction"
