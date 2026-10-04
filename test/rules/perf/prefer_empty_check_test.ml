open Rescript_linter

let checks_semantic_rules_test_support =
  let open Semantic_rules_test_support in
  [
    ( "list length",
      yes "prefer-empty-check" "let empty = values => values->List.length == 0"
    );
    ( "reverse list length",
      yes "prefer-empty-check" "let empty = values => 0 < values->List.length"
    );
    ( "array length",
      yes "prefer-empty-check" "let empty = values => values->Array.length < 1"
    );
    ( "string length",
      yes "prefer-empty-check" "let empty = value => value->String.length != 0"
    );
    ( "nonempty threshold",
      no "prefer-empty-check" "let many = value => value->Array.length > 3" );
    ( "module alias",
      yes "prefer-empty-check"
        "module Items = List\nlet empty = value => Items.length(value) == 0" );
    ( "value alias",
      yes "prefer-empty-check"
        "let length = List.length\nlet empty = value => length(value) == 0" );
    ( "open runtime",
      yes "prefer-empty-check"
        "open List\nlet empty = value => length(value) == 0" );
    ( "shadowed module",
      no "prefer-empty-check"
        "module List = {let length = _ => 0}\n\
         let empty = value => List.length(value) == 0" );
    ( "shadowed alias parameter",
      no "prefer-empty-check"
        "let length = List.length\nlet empty = length => length([]) == 0" );
    ( "project module shadows builtin",
      check
        ~context:
          { Semantic_model.default_context with project_modules = [ "List" ] }
        "prefer-empty-check" 0 "let empty = xs => List.length(xs) == 0" );
    ( "included runtime aliases",
      yes "prefer-empty-check"
        "module Collections = {include List}\n\
         let empty = xs => Collections.length(xs) == 0" );
    ( "local open runtime",
      yes "prefer-empty-check" "let empty = xs => {open List; length(xs) == 0}"
    );
    ( "nested recursive module exports shadow runtime",
      no "prefer-empty-check"
        "module Outer = {\n\
         module type S = {let length: int => int}\n\
         module rec List: S = {let length = x => x}\n\
         }\n\
         open Outer\n\
         let empty = List.length(1) == 0" );
    ( "unknown include invalidates all prior exports",
      no "prefer-empty-check"
        "module Outer = {\n\
         let length = List.length\n\
         module Values = Array\n\
         @val external size: int = \"size\"\n\
         module type S = {let length: int => int}\n\
         module rec Recursive: S = {let length = x => x}\n\
         include Missing\n\
         }\n\
         open Outer\n\
         let empty = xs => length(xs) == 0\n\
         let otherEmpty = xs => Values.length(xs) == 0" );
    ( "unordered imported aliases",
      with_signatures
        [
          ("Facade", "module Values = Provider.Values");
          ("Provider", "module Values = Array");
        ]
        (fun context ->
          check ~context "prefer-empty-check" 1
            "let empty = xs => Facade.Values.length(xs) == 0") );
    ( "known signature include retains runtime identity",
      with_signatures
        [ ("Facade", "include module type of List") ]
        (fun context ->
          check ~context "prefer-empty-check" 1
            "open Facade\nlet empty = xs => length(xs) == 0") );
    ( "unknown signature include quarantines open",
      with_signatures
        [ ("Facade", "include module type of Missing") ]
        (fun context ->
          check ~context "prefer-empty-check" 0
            "open Facade\nlet empty = xs => Array.length(xs) == 0") );
    ( "unknown local include quarantines open",
      no "prefer-empty-check"
        "module Facade = {include Missing}\n\
         open Facade\n\
         let empty = xs => Array.length(xs) == 0" );
    ( "inline include preserves values",
      yes "prefer-empty-check"
        "module Facade = {include {let length = List.length}}\n\
         let empty = xs => Facade.length(xs) == 0" );
    ( "module signature hides private values",
      no "prefer-empty-check"
        "module Facade: {let exposed: int} = {let length = List.length; let \
         exposed = 1}\n\
         let empty = xs => Facade.length(xs) == 0" );
    ( "module signature retains public identities",
      yes "prefer-empty-check"
        "module Facade: {let length: list<int> => int} = {let length = \
         List.length}\n\
         let empty = xs => Facade.length(xs) == 0" );
    ( "imported alias cycle remains unknown",
      with_signatures
        [
          ("First", "module Alias = Second.Alias");
          ("Second", "module Alias = First.Alias");
        ]
        (fun context ->
          check ~context "prefer-empty-check" 0
            "let empty = xs => First.Alias.length(xs) == 0") );
    ( "module unpack shadows runtime",
      no "prefer-empty-check"
        "module type S = {let length: int => int}\n\
         let check = (module(List: S), value) => List.length(value) == 0" );
    ( "module functor result remains unknown",
      no "prefer-empty-check"
        "module type S = {let length: int => int}\n\
         module Build = (Input: S) => Input\n\
         module List = Build({let length = x => x})\n\
         let empty = List.length(1) == 0" );
    ( "recursive modules shadow runtime",
      no "prefer-empty-check"
        "module type S = {let length: int => int}\n\
         module rec List: S = {let length = x => x}\n\
         let empty = List.length(1) == 0" );
    ( "reverse length at most zero",
      yes "prefer-empty-check" "let empty = xs => 0 >= Array.length(xs)" );
    ( "length at least one",
      yes "prefer-empty-check" "let nonempty = xs => Array.length(xs) >= 1" );
  ]

let () = Rule_test_runner.run checks_semantic_rules_test_support
