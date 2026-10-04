let metadata =
  Rule_metadata.
    {
      id = "test/no-conditional-test";
      category = Correctness;
      enabled_by_default = false;
    }

open Test_rule_support

let inspect emit registration =
  if registration.context.conditional then
    emit "test/no-conditional-test" "Register tests and suites unconditionally."
      registration.location
