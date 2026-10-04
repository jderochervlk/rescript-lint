let checks_exception_rules_test_support =
  let open Exception_rules_test_support in
  [
    ( "or-pattern catch-all",
      catch_all "try {read()} catch {| Not_found | _ => 0}" );
    ("wildcard catch", catch_all "try {read()} catch {| _ => 0}");
    ("variable catch", catch_all "try {read()} catch {| caught => log(caught)}");
    ( "aliased wildcard catch",
      catch_all "try {read()} catch {| _ as caught => log(caught)}" );
    ( "changed exception",
      catch_all "try {read()} catch {| caught => throw(Failure(\"changed\"))}"
    );
    ("wrong variable", catch_all "try {read()} catch {| caught => throw(other)}");
    ( "qualified variable",
      catch_all "try {read()} catch {| caught => throw(M.caught)}" );
    ( "logging before rethrow",
      catch_all "try {read()} catch {| caught => {log(caught); throw(caught)}}"
    );
    ( "rebound caught variable",
      catch_all
        "try {read()} catch {| caught => {let caught = other; throw(caught)}}"
    );
    ( "function body is not immediate",
      catch_all "try {read()} catch {| caught => () => throw(caught)}" );
    ( "switch exception catch",
      catch_all "switch read() {| exception _ => 0 | value => value}" );
    ( "switch exception or-pattern",
      catch_all
        "switch read() {| exception Not_found | exception _ => 0 | value => \
         value}" );
    ( "top-level value shadow",
      catch_all
        "let throw = identity\ntry {read()} catch {| caught => throw(caught)}"
    );
    ( "top-level primitive shadow",
      catch_all
        "external throw: exn => int = \"customThrow\"\n\
         try {read()} catch {| caught => throw(caught)}" );
    ( "parameter shadow",
      catch_all
        "let run = throw => try {read()} catch {| caught => throw(caught)}" );
    ( "nested pattern shadow",
      catch_all
        "let run = (throw, _) => try {read()} catch {| caught => throw(caught)}"
    );
    ( "catch pattern shadows throw",
      catch_all "try {read()} catch {| throw => throw(throw)}" );
    ( "switch arm shadows throw",
      catch_all
        "switch value {| Some(throw) => try {read()} catch {| caught => \
         throw(caught)} | None => 0}" );
    ( "local let shadows throw",
      catch_all
        "let run = () => {let throw = identity; try {read()} catch {| caught \
         => throw(caught)}}" );
    ( "recursive binding initializer scope",
      catch_all
        "let rec throw = caught => try {read()} catch {| caught => \
         throw(caught)}" );
    ( "nested recursive binding",
      catch_all
        "let run = () => {let rec throw = caught => try {read()} catch {| \
         caught => throw(caught)}; throw}" );
    ( "module shadow",
      catch_all
        "module Pervasives = Other\n\
         try {read()} catch {| caught => Pervasives.throw(caught)}" );
    ( "recursive module shadow",
      catch_all
        "module rec Pervasives: {} = {let run = try {read()} catch {| caught \
         => Pervasives.throw(caught)}}" );
    ( "local module shadow",
      catch_all
        "let run = () => {module Pervasives = Other; try {read()} catch {| \
         caught => Pervasives.throw(caught)}}" );
    ( "functor module shadow",
      catch_all
        "module F = (Pervasives: {}) => {let run = try {read()} catch {| \
         caught => Pervasives.throw(caught)}}" );
    ( "opaque open",
      catch_all "open Other\ntry {read()} catch {| caught => throw(caught)}" );
    ( "opaque local open",
      catch_all
        "let run = {open Other; try {read()} catch {| caught => throw(caught)}}"
    );
    ( "opaque include",
      catch_all "include Other\ntry {read()} catch {| caught => throw(caught)}"
    );
    ( "unrelated callee",
      catch_all "try {read()} catch {| caught => Other.throw(caught)}" );
    ( "nonidentifier callee",
      catch_all "try {read()} catch {| caught => (makeThrow())(caught)}" );
    ( "for-loop binding shadow",
      catch_all
        "for throw in 0 to 1 {try {read()} catch {| caught => throw(caught)}}"
    );
    ( "catch exact range",
      exact_range "no-catch-all-exception" "try {read()} catch {| _ => 0}" 22 23
    );
  ]

let () = Rule_test_runner.run checks_exception_rules_test_support
