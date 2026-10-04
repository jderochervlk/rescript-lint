let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ( "pure map fusion",
      yes "fuse-collection-pipeline"
        "let values = [1]->Array.map(x => x + 1)->Array.map(x => x * 2)" );
    ( "effectful map callbacks",
      no "fuse-collection-pipeline"
        "let values = [1]->Array.map(x => log(x))->Array.map(x => x * 2)" );
    ( "throwing integer callbacks do not fuse",
      no "fuse-collection-pipeline"
        "let values = [1]->Array.map(x => 10 / x)->Array.map(x => 20 / x)" );
    ( "promise creation is not a pure callback proof",
      no "fuse-collection-pipeline"
        "let values = [1]->Array.map(x => Promise.resolve(x))->Array.map(x => \
         x)" );
    ( "explicit pure callback contracts",
      yes "fuse-collection-pipeline"
        "@lint.pure\n\
         @val external normalize: int => int = \"normalize\"\n\
         @lint.pure\n\
         @val external render: int => string = \"render\"\n\
         let result = [1]->Array.map(normalize)->Array.map(render)" );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support
