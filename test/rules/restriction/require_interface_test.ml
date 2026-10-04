open Rescript_linter
open Project_rules_test_support

let project_checks root =
  let options =
    {
      Project_options.default with
      root = Some root;
      excluded_paths = [ "src/generated" ];
    }
  in
  let main = Filename.concat root "src/Main.res" in
  let api = Filename.concat root "src/Api.res" in
  let source = source main "let value = Api.old(1)\n" in
  [
    ( "require existing interface",
      check "require-interface" options
        { source with filename = api; text = "let old = x => x" }
        clean );
    ("require missing interface", check "require-interface" options source found);
  ]

let () =
  Rule_test_runner.run
    (Rule_test_runner.of_bools
       (Project_rules_test_support.with_project project_checks))
