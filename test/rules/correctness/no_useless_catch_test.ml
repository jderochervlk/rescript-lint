let checks_exception_rules_test_support =
  let open Exception_rules_test_support in
  [
    ( "immediate rethrow",
      useless "try {read()} catch {| caught => throw(caught)}" );
    ("legacy raise", useless "try {read()} catch {| caught => raise(caught)}");
    ( "qualified throw",
      useless "try {read()} catch {| caught => Pervasives.throw(caught)}" );
    ( "qualified raise",
      useless "try {read()} catch {| caught => Pervasives.raise(caught)}" );
    ( "constrained argument",
      useless "try {read()} catch {| caught => throw((caught: exn))}" );
    ( "constrained body",
      useless "try {read()} catch {| caught => (throw(caught): int)}" );
    ( "aliased constructor",
      useless "try {read()} catch {| Not_found as caught => throw(caught)}" );
    ( "aliased wildcard",
      useless "try {read()} catch {| _ as caught => throw(caught)}" );
    ( "constrained caught pattern",
      useless "try {read()} catch {| (caught: exn) => throw(caught)}" );
    ( "or-pattern rethrow",
      useless
        "try {read()} catch {| (Not_found as caught) | (Failure(_) as caught) \
         => throw(caught)}" );
    ( "multiple rethrows",
      useless
        "try {read()} catch {| Not_found as first => throw(first) | other => \
         throw(other)}" );
    ( "optional parameter default",
      useless
        "let run = (~throw=try {read()} catch {| caught => throw(caught)}) => \
         throw" );
    ( "nonrecursive binding initializer scope",
      useless "let throw = try {read()} catch {| caught => throw(caught)}" );
    ( "local scope does not leak",
      useless
        "let run = throw => throw\n\
         try {read()} catch {| caught => throw(caught)}" );
    ( "module initializer scope",
      useless
        "module Pervasives = {let run = try {read()} catch {| caught => \
         Pervasives.throw(caught)}}" );
    ( "unrelated module does not shadow",
      useless
        "module Other = {}\ntry {read()} catch {| caught => throw(caught)}" );
    ( "for-loop body",
      useless
        "for index in 0 to 1 {try {read()} catch {| caught => throw(caught)}}"
    );
    ( "try exact range",
      exact_range "no-useless-catch" "try {read()} catch {| e => throw(e)}" 0 36
    );
  ]

let () = Rule_test_runner.run checks_exception_rules_test_support
