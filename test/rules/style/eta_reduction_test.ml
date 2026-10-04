let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ( "eta runtime arity",
      yes "eta-reduction" "let parse = text => Int.fromString(text)" );
    ( "eta local arity",
      yes "eta-reduction"
        "let compute = (x: int) => x + 1\nlet wrapper = value => compute(value)"
    );
    ( "eta reordered arguments",
      no "eta-reduction"
        "let compute = (a, b) => a + b\nlet wrapper = (a, b) => compute(b, a)"
    );
    ( "eta excludes optional parameters",
      no "eta-reduction"
        "let compute = (~value=1) => value + 1\n\
         let wrapper = (~value=1) => compute(~value)" );
    ( "returned functions preserve outer arity",
      no "eta-reduction"
        "let curried = a => b => a + b\nlet wrapper = (a, b) => curried(a, b)"
    );
    ( "eta unknown arity boundary",
      boundary "eta-reduction" "let wrap = (fn, value) => fn(fn, value)" );
    ( "eta async excluded",
      no "eta-reduction" "let parse = async text => Int.fromString(text)" );
    ( "recursive eta excluded",
      no "eta-reduction" "let rec loop = value => loop(value)" );
    ( "typed eta narrowing excluded",
      no "eta-reduction"
        "let identity = x => x\n\
         let stringIdentity = (value: string) => identity(value)" );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support
