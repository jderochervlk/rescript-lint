open Rescript_linter

let checks_react_dom_rules_test_support =
  let open React_dom_rules_test_support in
  [
    ("array item key", yes "jsx-key" "[<li />]");
    ("array item has key", no "jsx-key" "[<li key=\"a\" />]");
    ("fragment array key", yes "jsx-key" "[<> <li /> </>]");
    ("mapped item key", yes "jsx-key" "items->Array.map(item => <li />)");
    ("direct mapped item key", yes "jsx-key" "Array.map(items, item => <li />)");
    ("mapped component key", yes "jsx-key" "items->Array.map(item => <Item />)");
    ( "mapped key supplied",
      no "jsx-key" "items->Array.map(item => <Item key={item.id} />)" );
    ( "indexed mapped key supplied",
      no "jsx-key"
        "items->Array.mapWithIndex((item, index) => <Item key={item.id} />)" );
    ( "mapped branch keys",
      check "jsx-key" 2
        "let view = items->Array.map(item => if item.ready {<li />} else {<li \
         />})" );
    ( "mapped case key",
      yes "jsx-key"
        "items->Array.map(item => switch item {| Some(value) => <li /> | None \
         => React.null})" );
    ( "mapped local binding",
      yes "jsx-key" "items->Array.map(item => {let title = item.title; <li />})"
    );
    ( "mapped sequence",
      yes "jsx-key" "items->Array.map(item => {Console.log(item); <li />})" );
    ( "mapped nested static child",
      no "jsx-key" "items->Array.map(item => <li key={item.id}> <span /> </li>)"
    );
    ("ordinary child doesn't need key", no "jsx-key" "<ul> <li /> </ul>");
    ( "spread might supply key",
      no "jsx-key" "items->Array.map(item => <li {...item} />)" );
    ("optional key unknown", no "jsx-key" "[<li key=?key />]");
    ("unrelated map ignored", no "jsx-key" "items->Custom.map(item => <li />)");
    ( "shadowed Array ignored",
      check "jsx-key" 0
        "module Array = Custom\nlet view = items->Array.map(item => <li />)" );
    ( "local module Array ignored",
      check "jsx-key" 0
        "let view = {module Array = Custom; items->Array.map(item => <li />)}"
    );
    ( "local open ignored",
      check "jsx-key" 0
        "let view = {open Custom; items->Array.map(item => <li />)}" );
    ("Belt mapped item", yes "jsx-key" "items->Belt.Array.map(item => <li />)");
    ( "interface",
      check ~kind:Source.Interface "jsx-key" 0 "let view: Jsx.element" );
    ("List rendered items", yes "jsx-key" "items->List.map(item => <li />)");
    ( "known Prelude preserves Array",
      with_prelude "jsx-key" 1 "let items: array<int>"
        "open Prelude\nlet view = items->Array.map(item => <li />)" );
    ( "known conflicting Prelude shadows Array",
      with_prelude "jsx-key" 0 "module Array: {let value: int}"
        "open Prelude\nlet view = items->Array.map(item => <li />)" );
    ( "project Array shadows runtime",
      check
        ~module_signatures:[ ("Array", []) ]
        "jsx-key" 0 "let view = items->Array.map(item => <li />)" );
    ( "functor Array shadows runtime",
      check "jsx-key" 0
        "module Make = (Array: {}) => {let view = items->Array.map(item => <li \
         />)}" );
  ]

let () = Rule_test_runner.run checks_react_dom_rules_test_support
