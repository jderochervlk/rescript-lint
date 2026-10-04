let checks_react_dom_rules_test_support =
  let open React_dom_rules_test_support in
  [
    ( "index converted key",
      yes "no-array-index-key"
        "items->Array.mapWithIndex((item, position) => <li \
         key={position->Int.toString} />)" );
    ( "index direct key",
      yes "no-array-index-key"
        "items->Array.mapWithIndex((item, position) => <li key={position} />)"
    );
    ( "index functional conversion",
      yes "no-array-index-key"
        "items->Array.mapWithIndex((item, position) => <li \
         key={Int.toString(position)} />)" );
    ( "stable item key",
      no "no-array-index-key"
        "items->Array.mapWithIndex((item, position) => <li key={item.id} />)" );
    ( "parameter name isn't evidence",
      no "no-array-index-key"
        "items->Array.map(index => <li key={index->Int.toString} />)" );
    ( "shadowed index binding",
      no "no-array-index-key"
        "items->Array.mapWithIndex((item, index) => {let index = item.id; <li \
         key={index} />})" );
    ( "shadowed index pattern",
      no "no-array-index-key"
        "items->Array.mapWithIndex((item, index) => switch item {| Some(index) \
         => <li key={index} /> | None => React.null})" );
    ( "static literal list index allowed",
      no "no-array-index-key"
        "[\"one\", \"two\"]->Array.mapWithIndex((item, index) => <li \
         key={index->Int.toString} />)" );
    ( "allocated literal items aren't static",
      yes "no-array-index-key"
        "[{id: \"a\"}]->Array.mapWithIndex((item, index) => <li \
         key={index->Int.toString} />)" );
    ( "nested function isn't renderer result",
      no "no-array-index-key"
        "items->Array.mapWithIndex((item, index) => () => <li \
         key={index->Int.toString} />)" );
    ( "shadowed Int conversion ignored",
      check "no-array-index-key" 0
        "module Int = Custom\n\
         let view = items->Array.mapWithIndex((item, index) => <li \
         key={index->Int.toString} />)" );
    ( "Belt index is first argument",
      yes "no-array-index-key"
        "items->Belt.Array.mapWithIndex((position, item) => <li \
         key={position->Int.toString} />)" );
    ( "Belt item is second argument",
      no "no-array-index-key"
        "items->Belt.Array.mapWithIndex((position, item) => <li \
         key={item->Int.toString} />)" );
    ( "List index is second argument",
      yes "no-array-index-key"
        "items->List.mapWithIndex((item, position) => <li \
         key={position->Int.toString} />)" );
    ( "Belt List index is first argument",
      yes "no-array-index-key"
        "items->Belt.List.mapWithIndex((position, item) => <li \
         key={position->Int.toString} />)" );
    ( "typed callback index",
      yes "no-array-index-key"
        "items->Array.mapWithIndex((item, position: int) => <li \
         key={position->Int.toString} />)" );
    ( "known Prelude preserves indexed Array",
      with_prelude "no-array-index-key" 1 "let items: array<int>"
        "open Prelude\n\
         let view = items->Array.mapWithIndex((item, index) => <li \
         key={index->Int.toString} />)" );
  ]

let () = Rule_test_runner.run checks_react_dom_rules_test_support

let () =
  Rule_test_runner.run
    [
      ( "typed index key",
        React_dom_rules_test_support.check "no-array-index-key" 1
          "let view = items->Array.mapWithIndex((item, index) => <div \
           key={(index: int)} />)" );
      ( "custom key conversion",
        React_dom_rules_test_support.check "no-array-index-key" 0
          "let view = items->Array.mapWithIndex((item, index) => <div \
           key={Custom.stringify(index)} />)" );
    ]
