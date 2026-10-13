open Rescript_linter

let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ( "top-level effect",
      yes "no-top-level-side-effect" "Console.log(\"loaded\")" );
    ( "deferred effect",
      no "no-top-level-side-effect"
        "let initialize = () => Console.log(\"loaded\")" );
    ( "entry module exempt",
      check
        ~context:{ Semantic_model.default_context with entry_module = true }
        "no-top-level-side-effect" 0 "Console.log(\"loaded\")" );
    ( "functor initialization is deferred",
      no "no-top-level-side-effect"
        "module type S = {}\n\
         module Make = (Input: S) => {Console.log(\"later\")}" );
    ( "nested array initialization effect",
      yes "no-top-level-side-effect"
        "let initialized = [Console.log(\"loaded\")]" );
    ( "nested record initialization effect",
      yes "no-top-level-side-effect"
        "let initialized = {value: Console.log(\"loaded\")}" );
    ( "unreachable initialization effect",
      no "no-top-level-side-effect"
        "let initialized = if false {Console.log(\"never\")} else {()}" );
    ( "mutation during initialization",
      yes "no-top-level-side-effect"
        "type state = {mutable value: int}\n\
         let state = {value: 0}\n\
         state.value = 1" );
    ( "assert during initialization",
      yes "no-top-level-side-effect" "assert(true)" );
    ( "deferred local module effect",
      no "no-top-level-side-effect"
        "let initialize = () => {module Inner = {Console.log(\"later\")}; ()}"
    );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support

let () =
  let scope = Semantic_runtime.initial_scope Semantic_model.default_context in
  let raw_checks =
    List.map
      (fun name ->
        ( name ^ " initialization effect",
          No_top_level_side_effect.effectful scope
            (Ast_helper.Exp.extension (Location.mknoloc name, PStr [])) ))
      [ "raw"; "bs.raw"; "res.raw" ]
  in
  let partial =
    Ast_helper.Exp.apply ~partial:true
      (Ast_helper.Exp.ident (Location.mknoloc (Longident.Lident "unknown")))
      []
  in
  Rule_test_runner.run
    (Rule_test_runner.of_bools
       (( "partial application is not an immediate effect",
          not (No_top_level_side_effect.effectful scope partial) )
       :: raw_checks))

let () =
  Rule_test_runner.run
    [
      ( "effectful true branch",
        Semantic_rules_test_support.check "no-top-level-side-effect" 1
          "let value = if true {Console.log(1)} else {()}" );
      ( "dynamic true branch",
        Semantic_rules_test_support.check "no-top-level-side-effect" 1
          "let value = if ready {Console.log(1)} else {()}" );
      ( "dynamic alternative",
        Semantic_rules_test_support.check "no-top-level-side-effect" 1
          "let value = if ready {()} else {Console.log(1)}" );
      ( "pure dynamic branches",
        Semantic_rules_test_support.check "no-top-level-side-effect" 0
          "let value = if ready {1} else {2}" );
      ( "effectful condition",
        Semantic_rules_test_support.check "no-top-level-side-effect" 1
          "let value = if {Console.log(1); true} {()} else {()}" );
      ( "effectful sequence",
        Semantic_rules_test_support.check "no-top-level-side-effect" 1
          "let value = {Console.log(1); ()}" );
      ( "sequence later effect",
        Semantic_rules_test_support.check "no-top-level-side-effect" 1
          "let value = {(); Console.log(1)}" );
      ( "tuple initialization",
        Semantic_rules_test_support.check "no-top-level-side-effect" 1
          "let value = (1, Console.log(1))" );
      ( "variant initialization",
        Semantic_rules_test_support.check "no-top-level-side-effect" 1
          "let value = #Loaded(Console.log(1))" );
      ( "constructor initialization",
        Semantic_rules_test_support.check "no-top-level-side-effect" 1
          "let value = Some(Console.log(1))" );
      ( "record update initialization",
        Semantic_rules_test_support.check "no-top-level-side-effect" 1
          "let value = {...base, value: Console.log(1)}" );
      ( "global evaluation",
        Semantic_rules_test_support.check "no-top-level-side-effect" 1
          "@val external evaluate: string => int = \"eval\"\n\
           let value = evaluate(\"1\")" );
      ( "await initialization",
        Semantic_rules_test_support.check "no-top-level-side-effect" 1
          "let value = await Promise.resolve(1)" );
    ]
