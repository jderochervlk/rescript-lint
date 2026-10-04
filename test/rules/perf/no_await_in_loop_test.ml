let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ( "independent loop",
      yes "no-await-in-loop"
        "let load = async () => {for i in 0 to 3 {await Promise.resolve()}}" );
    ( "unknown dependency loop",
      no "no-await-in-loop"
        "let load = async () => {for i in 0 to 3 {await fetch(i)}}" );
    ( "zero-iteration loop has no await",
      no "no-await-in-loop"
        "let run = async () => {for index in 3 to 0 {await Promise.resolve()}}"
    );
    ( "thenable promises do not prove independence",
      no "no-await-in-loop"
        "let run = async input => {for index in 0 to 3 {await \
         Promise.resolve(input)}}" );
    ( "explicit independent loop contract",
      yes "no-await-in-loop"
        "@lint.independent\n\
         @val external load: int => promise<unit> = \"load\"\n\
         let run = async () => {for index in 0 to 3 {await load(index)}}" );
    ( "awaited stored loop promise",
      no "no-await-in-loop"
        "let run = async (pending: promise<unit>) => {for i in 0 to 3 {await \
         pending}}" );
    ( "loop updates are not independent",
      no "no-await-in-loop"
        "let run = async state => {for i in 0 to 3 {state.value = await \
         fetch(i)}}" );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support

let () =
  Rule_test_runner.run
    [
      ( "unit resolved loop",
        Semantic_rules_test_support.check "no-await-in-loop" 1
          "let run = async () => {for index in 0 to 3 {await \
           Promise.resolve(())}}" );
      ( "boolean resolved loop",
        Semantic_rules_test_support.check "no-await-in-loop" 1
          "let run = async () => {for index in 0 to 3 {await \
           Promise.resolve(true)}}" );
      ( "integer resolved loop",
        Semantic_rules_test_support.check "no-await-in-loop" 1
          "let run = async () => {for index in 0 to 3 {await \
           Promise.resolve(1)}}" );
      ( "float resolved loop",
        Semantic_rules_test_support.check "no-await-in-loop" 1
          "let run = async () => {for index in 0 to 3 {await \
           Promise.resolve(1.0)}}" );
      ( "string resolved loop",
        Semantic_rules_test_support.check "no-await-in-loop" 1
          "let run = async () => {for index in 0 to 3 {await \
           Promise.resolve(\"value\")}}" );
    ]
