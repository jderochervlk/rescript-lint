type jsx_runtime = React_dom
type test_framework = Rescript_vitest_3

type t = {
  jsx_runtime : jsx_runtime option;
  test_framework : test_framework option;
  root : string option;
  restricted_modules : string list;
  entry_modules : string list;
  excluded_paths : string list;
  license : string;
  reanalyze_report : string option;
  limits : Policy_rules.limits;
  max_nested_describe : int;
  deep_equality_threshold : int;
}

let default =
  {
    jsx_runtime = None;
    test_framework = None;
    root = None;
    restricted_modules = [];
    entry_modules = [];
    excluded_paths = [];
    license = "MIT";
    reanalyze_report = None;
    limits = Policy_rules.default_limits;
    max_nested_describe = 5;
    deep_equality_threshold = 4;
  }
