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
  let source = source main "let value = Api.old(1)\n" in
  [
    ( "restricted canonical",
      check "no-restricted-modules"
        { options with restricted_modules = [ "Api" ] }
        source found );
    ( "restricted public type",
      check "no-restricted-modules"
        { options with restricted_modules = [ "Api" ] }
        { source with text = "let value: Api.public = 1" }
        found );
    ( "interface hides implementation type",
      check "no-restricted-modules"
        { options with restricted_modules = [ "Api" ] }
        { source with text = "let value: Api.hiddenType = \"hidden\"" }
        clean );
    ( "restricted public type in interface",
      check "no-restricted-modules"
        { options with restricted_modules = [ "Api" ] }
        Source.
          {
            filename = main ^ "i";
            kind = Interface;
            text = "let value: Api.public";
          }
        found );
    ( "restricted module alias",
      check "no-restricted-modules"
        { options with restricted_modules = [ "Api" ] }
        { source with text = "module A = Api\nlet value = A.old(1)" }
        found );
    ( "unrestricted",
      check "no-restricted-modules"
        { options with restricted_modules = [ "Database" ] }
        source clean );
  ]

let () =
  Rule_test_runner.run
    (Rule_test_runner.of_bools
       (Project_rules_test_support.with_project project_checks))
