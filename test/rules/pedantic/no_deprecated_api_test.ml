open Rescript_linter

let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ( "constrained module preserves declared deprecation",
      deprecated_constraint
        "module Api: {@deprecated(\"Use modern\") let old: int => int} = {let \
         old = x => x}\n\
         Api.old(1)"
        "Api.old" );
    ( "nested constrained module preserves declared deprecation",
      deprecated_constraint
        "module Api: {module Nested: {@deprecated(\"Use modern\") let old: int \
         => int}} = {module Nested = {let old = x => x}}\n\
         Api.Nested.old(1)"
        "Api.Nested.old" );
  ]

let checks_project_rules_test_support =
  let open Project_rules_test_support in
  Rule_test_runner.of_bools
    [
      ( "deprecated local module",
        check "no-deprecated-api" Project_options.default
          (source "api.res"
             "module Api = {@deprecated(\"Use modern\") let old = x => x}\n\
              let value = Api.old(1)")
          found );
      ( "deprecated local alias",
        check "no-deprecated-api" Project_options.default
          (source "api.res"
             "@deprecated(\"Use modern\") let old = x => x\n\
              let alias = old\n\
              let value = alias(1)")
          found );
      ( "deprecated shadow",
        check "no-deprecated-api" Project_options.default
          (source "api.res"
             "module Api = {@deprecated(\"Use modern\") let old = x => x}\n\
              let f = old => old(1)")
          clean );
    ]

let () =
  Rule_test_runner.run
    (List.concat
       [ checks_semantic_rules_test_support; checks_project_rules_test_support ])

let project_checks root =
  let open Project_rules_test_support in
  let options =
    {
      Project_options.default with
      root = Some root;
      excluded_paths = [ "src/generated" ];
    }
  in
  let main = Filename.concat root "src/Main.res" in
  let source = source main "let value = Api.old(1)\n" in
  [ ("interface precedence", check "no-deprecated-api" options source found) ]

let () =
  Rule_test_runner.run
    (Rule_test_runner.of_bools
       (Project_rules_test_support.with_project project_checks))
