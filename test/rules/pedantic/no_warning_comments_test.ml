open Rescript_linter

let checks_policy_rules_test_support =
  let open Policy_rules_test_support in
  [
    ("TODO comment", warning "// TODO: finish\nlet value = 1");
    ("case-insensitive warning", warning "// fixme: finish\nlet value = 1");
    ("block warning", warning "/* HACK: temporary */\nlet value = 1");
    ("doc warning", warning "/** TODO: finish */\nlet value = 1");
    ("module doc warning", warning "/*** TODO: finish */\nlet value = 1");
    ( "record field documentation is inspected",
      warning "type value = {/** TODO */ field: int}" );
    ( "warning in interface",
      check ~kind:Source.Interface [ "no-warning-comments" ]
        "// TODO\nlet value: int" );
    ( "multiple terms one finding",
      warning "// FIXME TODO HACK TODO\nlet value = 1" );
    ( "one finding per comment",
      check
        [ "no-warning-comments"; "no-warning-comments" ]
        "// TODO\nlet value = 1 // HACK\n" );
    ( "comment location",
      check_range "no-warning-comments" 1 1 1 8 "// TODO\nlet value = 1" );
  ]

let () = Rule_test_runner.run checks_policy_rules_test_support
