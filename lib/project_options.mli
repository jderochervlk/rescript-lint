type jsx_runtime = React_dom
type test_framework = Rescript_vitest_3
type throws_runtime = Rescript_12_3_1

type t = {
  jsx_runtime : jsx_runtime option;
  test_framework : test_framework option;
  throws_runtime : throws_runtime option;
  throws_dependencies : string list;
  root : string option;
  restricted_modules : string list;
  entry_modules : string list;
  excluded_paths : string list;
  license : string;
  reanalyze_report : string option;
  limits : Policy_rules.limits;
  warning_comments : Policy_rules.warning_policy;
  max_nested_describe : int;
  deep_equality_threshold : int;
}

val default : t
