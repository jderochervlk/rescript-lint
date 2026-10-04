let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ( "array shallow equality",
      yes "no-unintended-shallow-equality" "let same = [1] === [1]" );
    ( "typed array equality",
      yes "no-unintended-shallow-equality"
        "let same = (left: array<int>, right: array<int>) => left === right" );
    ( "primitive shallow equality",
      no "no-unintended-shallow-equality" "let same = 1 === 1" );
    ( "identity annotation",
      no "no-unintended-shallow-equality"
        "let same = @lint.identity ([1] === [1])" );
    ( "unknown shallow types",
      boundary "no-unintended-shallow-equality"
        "let same = (left, right) => left === right" );
    ( "payload-free variant primitive",
      no "no-unintended-shallow-equality"
        "type item = Empty | Value(int)\nlet same = Empty === Empty" );
    ( "binding identity annotation",
      no "no-unintended-shallow-equality"
        "@lint.identity\nlet same = [1] === [2]" );
    ( "tuple shallow equality",
      yes "no-unintended-shallow-equality" "let same = (1, 2) === (1, 2)" );
    ( "record shallow equality",
      yes "no-unintended-shallow-equality"
        "let same = {value: 1} === {value: 1}" );
    ( "list shallow equality",
      yes "no-unintended-shallow-equality" "let same = list{1} === list{2}" );
    ( "option compound shallow equality",
      yes "no-unintended-shallow-equality" "let same = Some([1]) === Some([2])"
    );
    ( "result shallow equality",
      yes "no-unintended-shallow-equality" "let same = Ok(1) === Ok(2)" );
    ( "array initializer result type",
      yes "no-unintended-shallow-equality"
        "let value = Array.fromInitializer(~length=3, i => i)\n\
         let same = value === []" );
    ( "array filter result type",
      yes "no-unintended-shallow-equality"
        "let value = Array.filter([1], _ => true)\nlet same = value === []" );
    ( "array flatMap result type",
      yes "no-unintended-shallow-equality"
        "let value = Array.flatMap([1], i => [i])\nlet same = value === []" );
    ( "array concat result type",
      yes "no-unintended-shallow-equality"
        "let value = Array.concat([1], [2])\nlet same = value === []" );
    ( "list map result type",
      yes "no-unintended-shallow-equality"
        "let value = List.map(list{1}, i => i)\nlet same = value === list{2}" );
    ( "list filter result type",
      yes "no-unintended-shallow-equality"
        "let value = List.filter(list{1}, _ => true)\n\
         let same = value === list{2}" );
    ( "list concat result type",
      yes "no-unintended-shallow-equality"
        "let value = List.concat(list{1}, list{2})\n\
         let same = value === list{2}" );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support
