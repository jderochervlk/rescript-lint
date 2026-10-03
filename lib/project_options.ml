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
  restrictions : Restriction_policy.t;
  entry_modules : string list;
  excluded_paths : string list;
  license : string;
  reanalyze_report : string option;
  limits : Policy_rules.limits;
  warning_comments : Policy_rules.warning_policy;
  max_nested_describe : int;
  deep_equality_threshold : int;
  max_lines : int;
  max_switch_cases : int;
}

let default =
  {
    jsx_runtime = None;
    test_framework = None;
    throws_runtime = None;
    throws_dependencies = [];
    root = None;
    restricted_modules = [];
    restrictions = Restriction_policy.empty;
    entry_modules = [];
    excluded_paths = [];
    license = "MIT";
    reanalyze_report = None;
    limits = Policy_rules.default_limits;
    warning_comments = Policy_rules.default_warning_policy;
    max_nested_describe = 5;
    deep_equality_threshold = 4;
    max_lines = 300;
    max_switch_cases = 10;
  }
