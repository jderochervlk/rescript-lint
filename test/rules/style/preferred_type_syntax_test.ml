let checks_new_policy_rules_test_support =
  let open New_policy_rules_test_support in
  [
    ( "dict annotation",
      check "preferred-type-syntax" 1 "let f = (x: Dict.t<int>) => x" );
    ( "dict binding",
      check "preferred-type-syntax" 1 "let value: Dict.t<int> = dict{}" );
    ( "dict result",
      check "preferred-type-syntax" 1 "let f = (): Dict.t<int> => dict{}" );
    ( "dict external",
      check "preferred-type-syntax" 1
        "@val external value: Dict.t<int> = \"value\"" );
    ( "dict interface",
      check ~kind:Interface "preferred-type-syntax" 1 "let value: Dict.t<int>"
    );
    ( "dict alias",
      check "preferred-type-syntax" 1 "module D = Dict\ntype values = D.t<int>"
    );
    ( "dict open",
      check "preferred-type-syntax" 1 "open Dict\ntype values = t<int>" );
    ( "dict stdlib",
      check "preferred-type-syntax" 1 "type values = Stdlib.Dict.t<int>" );
    ( "dict nested",
      check "preferred-type-syntax" 2 "type values = Dict.t<Dict.t<int>>" );
    ( "dict shadow",
      check "preferred-type-syntax" 0
        "module Dict = {type t<'a> = array<'a>}\ntype values = Dict.t<int>" );
    ( "dict type shadow",
      check "preferred-type-syntax" 0
        "open Dict\ntype t<'a> = array<'a>\ntype values = t<int>" );
    ( "dict unknown open",
      check "preferred-type-syntax" 0 "open Other\ntype values = Dict.t<int>" );
    ( "dict parameter scope",
      check "preferred-type-syntax" 0
        "module Make = (Dict: {type t<'a>}) => {type values = Dict.t<int>}" );
    ( "dict signature constraint",
      check "preferred-type-syntax" 1
        "module Values: {let value: Dict.t<int>} = {let value = dict{}}" );
    ( "dict module type",
      check "preferred-type-syntax" 1
        "module type Values = {let value: Dict.t<int>}" );
    ( "dict interface open",
      check ~kind:Interface "preferred-type-syntax" 1
        "open Dict\nlet value: t<int>" );
    ( "dict interface shadow",
      check ~kind:Interface "preferred-type-syntax" 0
        "module Dict: {type t<'a>}\nlet value: Dict.t<int>" );
    ( "dict include",
      check "preferred-type-syntax" 1 "include Dict\ntype values = t<int>" );
    ( "module type constraint",
      check "preferred-type-syntax" 1
        "module type Values = {type t} with type t = Dict.t<int>" );
    ( "signature type constraint",
      check ~kind:Interface "preferred-type-syntax" 1
        "module Values: {type t} with type t = Dict.t<int>" );
    ("project Dict shadows runtime", project_dict_shadow);
    ( "signature recursive type shadow",
      check ~kind:Interface "preferred-type-syntax" 0
        "open Dict\ntype rec t<'a> = t<'a>" );
    ( "signature recursive module shadow",
      check ~kind:Interface "preferred-type-syntax" 0
        "module rec Dict: {type t<'a>; let value: Dict.t<int>}" );
    ( "signature recursive module type use",
      check ~kind:Interface "preferred-type-syntax" 1
        "module rec Values: {let value: Dict.t<int>}" );
  ]
  @ List.concat_map
      (fun (id, bad, good) ->
        [
          (id ^ " positive", check id 1 bad);
          (id ^ " negative", check id 0 good);
          (id ^ " nested", check id 1 ("module Nested = {" ^ bad ^ "}"));
        ])
      [
        ( "preferred-type-syntax",
          "type names = Dict.t<string>",
          "type names = dict<string>" );
      ]

let () = Rule_test_runner.run checks_new_policy_rules_test_support
