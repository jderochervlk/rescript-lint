let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ( "computed float equality",
      yes "no-float-equality"
        "let same = (left: float, right: float) => left == right" );
    ( "float sentinel",
      no "no-float-equality" "let same = (left: float) => left == 0.0" );
    ( "exact float annotation",
      no "no-float-equality"
        "let same = (left: float, right: float) => @lint.exactFloat (left == \
         right)" );
    ( "module exports retain declared record types",
      yes "no-float-equality"
        "module Values = {type t = {amount: float}; let current: t = {amount: \
         1.5}}\n\
         let expected = 1.5\n\
         let same = Values.current.amount == expected" );
    ( "nested signature types",
      with_signatures
        [
          ( "Api",
            "type state = {value: float}\nmodule Nested: {let current: state}"
          );
        ]
        (fun context ->
          check ~context "no-float-equality" 1
            "let compare = (expected: float) => Api.Nested.current.value == \
             expected") );
    ( "float unknown boundary",
      boundary "no-float-equality" "let same = (left, right) => left == right"
    );
    ( "record float field",
      yes "no-float-equality"
        "type state = {value: float}\n\
         let same = (left: state, right: state) => left.value == right.value" );
    ( "computed floats",
      yes "no-float-equality"
        "let same = (left: float, right: float) => (left +. 1.0) == (right *. \
         2.0)" );
    ( "array get preserves element type",
      yes "no-float-equality"
        "let same = (xs: array<float>, expected: float) => Array.getUnsafe(xs, \
         0) == expected" );
    ( "option pattern preserves payload",
      yes "no-float-equality"
        "let same = (value: option<float>, expected: float) => switch value {| \
         Some(actual) => actual == expected | None => false}" );
    ( "result pattern preserves payload",
      yes "no-float-equality"
        "let same = (value: result<float, string>, expected: float) => switch \
         value {| Ok(actual) => actual == expected | Error(_) => false}" );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support

let () =
  Rule_test_runner.run
    [
      ( "right computed float",
        Semantic_rules_test_support.check "no-float-equality" 1
          "let same = (left: int, right: float) => left == right" );
      ( "right float sentinel",
        Semantic_rules_test_support.check "no-float-equality" 0
          "let same = (left: float) => left == 0.0" );
      ( "left float sentinel",
        Semantic_rules_test_support.check "no-float-equality" 0
          "let same = (right: float) => 0.0 == right" );
      ( "right unknown boundary",
        Semantic_rules_test_support.check "no-float-equality" 0
          "let same = (left: int, right) => left == right" );
      ( "right unknown with literal",
        Semantic_rules_test_support.check "no-float-equality" 0
          "let same = right => 0 == right" );
      ( "left unknown with literal",
        Semantic_rules_test_support.check "no-float-equality" 0
          "let same = left => left == 0" );
    ]
