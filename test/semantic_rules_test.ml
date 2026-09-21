open Rescript_linter

let source text =
  Source.{ filename = "semantic.res"; text; kind = Implementation }

let diagnostics ?(context = Semantic_model.default_context) text =
  let source = source text in
  Result.bind (Parser.parse source) (Semantic_rules.check ~context ~source)

let check ?context rule expected text =
  match diagnostics ?context text with
  | Error error -> Error (Lint_error.render error)
  | Ok diagnostics ->
      let actual =
        List.filter
          (fun (diagnostic : Diagnostic.t) -> diagnostic.rule = rule)
          diagnostics
        |> List.length
      in
      if actual = expected then Ok ()
      else
        Error
          (Printf.sprintf "%s: expected %d, got %d for %s" rule expected actual
             text)

let yes rule text = check rule 1 text
let no rule text = check rule 0 text

let boundary rule text =
  let context = { Semantic_model.default_context with enabled = [ rule ] } in
  match diagnostics ~context text with
  | Error (Lint_error.Analysis_errors _) -> Ok ()
  | Error error -> Error (Lint_error.render error)
  | Ok _ -> Error "Expected an explicit analysis boundary"

let imported =
  let source =
    Source.
      {
        filename = "Api.resi";
        kind = Interface;
        text =
          "let compute: int => promise<int>\n\
           let validate: string => result<int, string>\n\
           @deprecated(\"Use modern\")\n\
           let legacy: int => int";
      }
  in
  match Parser.parse source with
  | Ok (Interface signature) ->
      Ok
        {
          Semantic_model.default_context with
          module_signatures = [ ("Api", signature) ];
        }
  | Ok _ -> Error "Expected interface"
  | Error error -> Error (Lint_error.render error)

let imported_check rule text =
  Result.bind imported (fun context -> check ~context rule 1 text)

let with_signatures entries run =
  let parsed =
    List.fold_left
      (fun result (name, text) ->
        Result.bind result (fun signatures ->
            let source =
              Source.{ filename = name ^ ".resi"; kind = Interface; text }
            in
            match Parser.parse source with
            | Ok (Interface signature) -> Ok (signatures @ [ (name, signature) ])
            | Ok _ -> Error "Expected signature"
            | Error error -> Error (Lint_error.render error)))
      (Ok []) entries
  in
  Result.bind parsed (fun module_signatures ->
      run
        {
          Semantic_model.default_context with
          module_signatures;
          project_modules = List.map fst entries;
        })

let deprecated_constraint text reference =
  Result.bind
    (Rule_config.set Rule_config.default ~id:"no-deprecated-api" ~enabled:true)
    (fun config ->
      Result.bind
        (Result.map_error Lint_error.render
           (Linter.lint_source_with_rules config (source text)))
        (fun diagnostics ->
          match
            List.filter
              (fun (item : Diagnostic.t) -> item.rule = "no-deprecated-api")
              diagnostics
          with
          | [ item ]
            when item.message = "This API is deprecated. Use modern"
                 && item.fixes = []
                 && String.sub text item.range.start.byte_offset
                      (item.range.finish.byte_offset
                     - item.range.start.byte_offset)
                    = reference ->
              Ok ()
          | _ -> Error "Constrained public deprecation metadata was lost"))

let checks =
  [
    ( "self compare",
      yes "no-self-compare" "let value = 1\nlet same = value == value" );
    ( "different values",
      no "no-self-compare"
        "let left = 1\nlet right = 2\nlet same = left == right" );
    ( "self compare aliases",
      yes "no-self-compare"
        "let value = 1\nlet alias = value\nlet same = value === alias" );
    ("call comparison", no "no-self-compare" "let value = read() == read()");
    ( "field comparison",
      no "no-self-compare" "let check = value => value.field == value.field" );
    ( "float self comparison",
      yes "no-self-compare" "let check = (value: float) => value != value" );
    ( "array shallow equality",
      yes "no-unintended-shallow-equality" "let same = [1] === [1]" );
    ( "typed array equality",
      yes "no-unintended-shallow-equality"
        "let same = (left: array<int>, right: array<int>) => left === right" );
    ( "primitive shallow equality",
      no "no-unintended-shallow-equality" "let same = 1 === 1" );
    ( "identity annotation",
      no "no-unintended-shallow-equality"
        "let same = @lint.identity ([1] === [1])" );
    ( "unknown shallow types",
      boundary "no-unintended-shallow-equality"
        "let same = (left, right) => left === right" );
    ( "deep array comparison",
      yes "no-expensive-deep-equality" "let same = [1] == [2]" );
    ( "primitive deep equality",
      no "no-expensive-deep-equality" "let same = 1 == 2" );
    ( "deep record comparison",
      yes "no-expensive-deep-equality"
        "type state = {a: int, b: int, c: int}\n\
         let same = (left: state, right: state) => left == right" );
    ( "computed float equality",
      yes "no-float-equality"
        "let same = (left: float, right: float) => left == right" );
    ( "float sentinel",
      no "no-float-equality" "let same = (left: float) => left == 0.0" );
    ( "exact float annotation",
      no "no-float-equality"
        "let same = (left: float, right: float) => @lint.exactFloat (left == \
         right)" );
    ( "fixed list pattern",
      yes "prefer-pattern-check"
        "let same = (items: list<int>) => items == list{1, 2}" );
    ( "efficient empty list comparison",
      no "prefer-pattern-check"
        "let same = (items: list<int>) => items == list{}" );
    ( "efficient None comparison",
      no "prefer-pattern-check"
        "let same = (value: option<int>) => value == None" );
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
    ( "partial head",
      yes "no-partial-function" "let first = value => List.headOrThrow(value)"
    );
    ( "partial result",
      yes "no-partial-function" "let unwrap = value => Result.getExn(value)" );
    ( "safe head",
      no "no-partial-function" "let first = value => List.head(value)" );
    ( "invalid-value inventory separate",
      no "no-partial-function" "let first = value => Array.getUnsafe(value, 0)"
    );
    ("raw code", yes "no-dynamic-code" "let value = %raw(\"eval(input)\")");
    ( "ordinary external",
      no "no-dynamic-code"
        "@val external evaluate: string => int = \"evaluate\"" );
    ( "resolved external eval",
      yes "no-dynamic-code"
        "@val external evaluate: string => int = \"eval\"\n\
         let run = code => evaluate(code)" );
    ( "scoped eval is not global eval",
      no "no-dynamic-code"
        "@val @scope(\"Safe\") external evaluate: string => int = \"eval\"\n\
         let run = code => evaluate(code)" );
    ( "shared mutable record",
      yes "no-shared-array-initializer"
        "type item = {mutable selected: bool}\n\
         let values = Array.make(~length=3, {selected: false})" );
    ( "shared nested array",
      yes "no-shared-array-initializer" "let values = Array.make(~length=3, [])"
    );
    ( "immutable record initializer",
      no "no-shared-array-initializer"
        "type item = {selected: bool}\n\
         let values = Array.make(~length=3, {selected: false})" );
    ( "single initializer slot",
      no "no-shared-array-initializer" "let values = Array.make(~length=1, [])"
    );
    ( "promise ignored",
      yes "no-floating-promise" "let save = () => Promise.resolve(1)->ignore" );
    ("promise wildcard", yes "no-floating-promise" "let _ = Promise.resolve(1)");
    ( "promise stored",
      no "no-floating-promise" "let promise = Promise.resolve(1)" );
    ( "promise through local block",
      yes "no-floating-promise"
        "let save = () => {let promise = Promise.resolve(1); promise}\n\
         let run = () => save()->ignore" );
    ( "unknown discarded promise boundary",
      boundary "no-floating-promise" "let run = () => unknown()->ignore" );
    ( "unknown discarded result boundary",
      boundary "no-ignored-result" "let run = () => unknown()->ignore" );
    ( "shadowed ignore",
      no "no-floating-promise"
        "let ignore = promise => promise\n\
         let result = ignore(Promise.resolve(1))" );
    ( "imported promise",
      imported_check "no-floating-promise"
        "let save = () => Api.compute(1)->ignore" );
    ("async without await", yes "require-await" "let load = async () => 42");
    ( "async with await",
      no "require-await" "let load = async () => await Promise.resolve(42)" );
    ( "known promise adapter",
      no "require-await" "let load = async () => Promise.resolve(42)" );
    ( "unknown adapter boundary",
      boundary "require-await" "let load = async () => fetch()" );
    ( "independent loop",
      yes "no-await-in-loop"
        "let load = async () => {for i in 0 to 3 {await Promise.resolve()}}" );
    ( "unknown dependency loop",
      no "no-await-in-loop"
        "let load = async () => {for i in 0 to 3 {await fetch(i)}}" );
    ( "forwarded recursion parameter",
      yes "only-used-in-recursion"
        "let rec repeat = (count, config) => if count == 0 {()} else \
         {repeat(count - 1, config)}" );
    ( "used recursion parameter",
      no "only-used-in-recursion"
        "let rec repeat = (count, config) => if count == config {()} else \
         {repeat(count - 1, config)}" );
    ( "changed recursion parameter",
      no "only-used-in-recursion"
        "let rec repeat = (count, config) => if count == 0 {()} else \
         {repeat(count - 1, config + 1)}" );
    ( "eta runtime arity",
      yes "eta-reduction" "let parse = text => Int.fromString(text)" );
    ( "eta local arity",
      yes "eta-reduction"
        "let compute = (x: int) => x + 1\nlet wrapper = value => compute(value)"
    );
    ( "eta reordered arguments",
      no "eta-reduction"
        "let compute = (a, b) => a + b\nlet wrapper = (a, b) => compute(b, a)"
    );
    ( "eta excludes optional parameters",
      no "eta-reduction"
        "let compute = (~value=1) => value + 1\n\
         let wrapper = (~value=1) => compute(~value)" );
    ( "returned functions preserve outer arity",
      no "eta-reduction"
        "let curried = a => b => a + b\nlet wrapper = (a, b) => curried(a, b)"
    );
    ( "eta unknown arity boundary",
      boundary "eta-reduction" "let wrap = (fn, value) => fn(fn, value)" );
    ( "eta async excluded",
      no "eta-reduction" "let parse = async text => Int.fromString(text)" );
    ( "result ignored",
      yes "no-ignored-result" "let validate = () => Ok(1)->ignore" );
    ("result wildcard", yes "no-ignored-result" "let _ = Error(\"invalid\")");
    ("result stored", no "no-ignored-result" "let result = Ok(1)");
    ( "imported result",
      imported_check "no-ignored-result"
        "let validate = () => Api.validate(\"input\")->ignore" );
    ( "pure map fusion",
      yes "fuse-collection-pipeline"
        "let values = [1]->Array.map(x => x + 1)->Array.map(x => x * 2)" );
    ( "effectful map callbacks",
      no "fuse-collection-pipeline"
        "let values = [1]->Array.map(x => log(x))->Array.map(x => x * 2)" );
    ( "string accumulating concat",
      yes "no-accumulating-concat"
        "let value = [\"a\"]->Array.reduce(\"\", (acc, part) => acc ++ part)" );
    ( "nonaccumulating callback",
      no "no-accumulating-concat"
        "let value = [\"a\"]->Array.reduce(\"\", (_acc, part) => part ++ \
         \"suffix\")" );
    ( "top-level effect",
      yes "no-top-level-side-effect" "Console.log(\"loaded\")" );
    ( "deferred effect",
      no "no-top-level-side-effect"
        "let initialize = () => Console.log(\"loaded\")" );
    ( "entry module exempt",
      check
        ~context:{ Semantic_model.default_context with entry_module = true }
        "no-top-level-side-effect" 0 "Console.log(\"loaded\")" );
    ( "redundant mutual recursion",
      yes "no-redundant-mutual-recursion"
        "let rec increment = x => x + 1 and double = x => x * 2" );
    ( "required mutual recursion",
      no "no-redundant-mutual-recursion"
        "let rec even = n => if n == 0 {true} else {odd(n - 1)} and odd = n => \
         if n == 0 {false} else {even(n - 1)}" );
    ( "single recursive function",
      no "no-redundant-mutual-recursion"
        "let rec repeat = n => if n == 0 {()} else {repeat(n - 1)}" );
    ( "manual list map",
      yes "prefer-standard-combinator"
        "let rec doubleAll = items => switch items {| list{} => list{} | \
         list{head, ...tail} => list{head * 2, ...doubleAll(tail)}}" );
    ( "effectful recursion excluded",
      no "prefer-standard-combinator"
        "let rec mapped = items => switch items {| list{} => list{} | \
         list{head, ...tail} => list{log(head), ...mapped(tail)}}" );
    ( "standalone attribute excluded",
      no "no-dynamic-code" "@@example(%raw(\"eval(input)\"))" );
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
    ( "conflicting record mutability is unknown",
      no "no-shared-array-initializer"
        "type mutableItem = {mutable selected: bool}\n\
         type fixedItem = {selected: bool}\n\
         let values = Array.make(~length=3, {selected: false})" );
    ( "payload-free variant primitive",
      no "no-unintended-shallow-equality"
        "type item = Empty | Value(int)\nlet same = Empty === Empty" );
  ]

let additional_checks =
  [
    ( "module exports retain declared record types",
      yes "no-float-equality"
        "module Values = {type t = {amount: float}; let current: t = {amount: \
         1.5}}\n\
         let expected = 1.5\n\
         let same = Values.current.amount == expected" );
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
    ( "functor initialization is deferred",
      no "no-top-level-side-effect"
        "module type S = {}\n\
         module Make = (Input: S) => {Console.log(\"later\")}" );
    ( "imported alias cycle remains unknown",
      with_signatures
        [
          ("First", "module Alias = Second.Alias");
          ("Second", "module Alias = First.Alias");
        ]
        (fun context ->
          check ~context "prefer-empty-check" 0
            "let empty = xs => First.Alias.length(xs) == 0") );
    ( "nested signature types",
      with_signatures
        [
          ( "Api",
            "type state = {value: float}\nmodule Nested: {let current: state}"
          );
        ]
        (fun context ->
          check ~context "no-float-equality" 1
            "let compare = (expected: float) => Api.Nested.current.value == \
             expected") );
    ( "promise type alias",
      yes "no-floating-promise"
        "let run = (pending: Promise.t<int>) => ignore(pending)" );
    ( "result type alias",
      yes "no-ignored-result"
        "let run = (result: Result.t<int, string>) => ignore(result)" );
    ( "zero-iteration loop has no await",
      no "no-await-in-loop"
        "let run = async () => {for index in 3 to 0 {await Promise.resolve()}}"
    );
    ( "external global reads are not stable",
      no "no-self-compare"
        "@val external current: int = \"current\"\n\
         let same = current == current" );
    ( "external snapshot is distinct from later global read",
      no "no-self-compare"
        "@val external current: int = \"current\"\n\
         let captured = current\n\
         let same = captured == current" );
    ( "captured external snapshot is stable",
      yes "no-self-compare"
        "@val external current: int = \"current\"\n\
         let captured = current\n\
         let same = captured == captured" );
    ( "throwing integer callbacks do not fuse",
      no "fuse-collection-pipeline"
        "let values = [1]->Array.map(x => 10 / x)->Array.map(x => 20 / x)" );
    ( "thenable promises do not prove independence",
      no "no-await-in-loop"
        "let run = async input => {for index in 0 to 3 {await \
         Promise.resolve(input)}}" );
    ( "promise creation is not a pure callback proof",
      no "fuse-collection-pipeline"
        "let values = [1]->Array.map(x => Promise.resolve(x))->Array.map(x => \
         x)" );
    ( "nested array initialization effect",
      yes "no-top-level-side-effect"
        "let initialized = [Console.log(\"loaded\")]" );
    ( "nested record initialization effect",
      yes "no-top-level-side-effect"
        "let initialized = {value: Console.log(\"loaded\")}" );
    ( "unreachable initialization effect",
      no "no-top-level-side-effect"
        "let initialized = if false {Console.log(\"never\")} else {()}" );
    ( "recursive labels changed",
      no "only-used-in-recursion"
        "let rec swap = (~left, ~right) => swap(~right=left, ~left=right)" );
    ( "binding async adapter annotation",
      no "require-await" "@lint.promiseAdapter\nlet run = async () => 42" );
    ( "binding identity annotation",
      no "no-unintended-shallow-equality"
        "@lint.identity\nlet same = [1] === [2]" );
    ( "explicit independent loop contract",
      yes "no-await-in-loop"
        "@lint.independent\n\
         @val external load: int => promise<unit> = \"load\"\n\
         let run = async () => {for index in 0 to 3 {await load(index)}}" );
    ( "explicit pure callback contracts",
      yes "fuse-collection-pipeline"
        "@lint.pure\n\
         @val external normalize: int => int = \"normalize\"\n\
         @lint.pure\n\
         @val external render: int => string = \"render\"\n\
         let result = [1]->Array.map(normalize)->Array.map(render)" );
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
    ( "self comparison unknown boundary",
      boundary "no-self-compare" "let same = value => value == value" );
    ( "float unknown boundary",
      boundary "no-float-equality" "let same = (left, right) => left == right"
    );
    ( "deep unknown boundary",
      boundary "no-expensive-deep-equality"
        "let same = (left, right) => left == right" );
    ( "tuple shallow equality",
      yes "no-unintended-shallow-equality" "let same = (1, 2) === (1, 2)" );
    ( "record shallow equality",
      yes "no-unintended-shallow-equality"
        "let same = {value: 1} === {value: 1}" );
    ( "list shallow equality",
      yes "no-unintended-shallow-equality" "let same = list{1} === list{2}" );
    ( "option compound shallow equality",
      yes "no-unintended-shallow-equality" "let same = Some([1]) === Some([2])"
    );
    ( "result shallow equality",
      yes "no-unintended-shallow-equality" "let same = Ok(1) === Ok(2)" );
    ( "tuple deep risk",
      yes "no-expensive-deep-equality" "let same = (1, 2, 3) == (1, 2, 4)" );
    ( "option deep risk",
      yes "no-expensive-deep-equality" "let same = Some([1]) == Some([2])" );
    ( "payload variant deep risk",
      yes "no-expensive-deep-equality"
        "type status = Active(int)\n\
         let same = (left: status, right: status) => left == right" );
    ( "literal variant pattern",
      yes "prefer-pattern-check"
        "type status = Active(int)\n\
         let same = (left: status) => left == Active(1)" );
    ( "dynamic list pattern excluded",
      no "prefer-pattern-check"
        "let same = (items: list<int>, value) => items == list{value}" );
    ( "reverse length at most zero",
      yes "prefer-empty-check" "let empty = xs => 0 >= Array.length(xs)" );
    ( "length at least one",
      yes "prefer-empty-check" "let nonempty = xs => Array.length(xs) >= 1" );
    ( "partial indexed list",
      yes "no-partial-function" "let read = xs => List.getOrThrow(xs, 0)" );
    ( "partial indexed legacy list",
      yes "no-partial-function" "let read = xs => List.getExn(xs, 0)" );
    ("safe primitive ignore", no "no-ignored-result" "let run = () => ignore(1)");
    ( "promise-specific ignore",
      yes "no-floating-promise"
        "let run = () => Promise.ignore(Promise.resolve(1))" );
    ( "result-specific ignore",
      yes "no-ignored-result" "let run = () => Result.ignore(Ok(1))" );
    ( "immutable array fill",
      no "no-shared-array-initializer" "let values = Array.make(~length=3, 0)"
    );
    ( "computed function callee",
      no "no-floating-promise" "let value = make()(1, 2)" );
    ( "named reduce callback",
      no "no-accumulating-concat"
        "let combine = (a, b) => a + b\n\
         let value = Array.reduce([1], 0, combine)" );
    ( "nonconcat reducer",
      no "no-accumulating-concat"
        "let value = Array.reduce([1], 0, (acc, item) => acc + item)" );
    ( "list accumulating concat",
      yes "no-accumulating-concat"
        "let value = List.reduce(list{\"a\"}, \"\", (acc, item) => acc ++ item)"
    );
    ( "await in nested function only",
      check "require-await" 1
        "let outer = async () => {let inner = async () => await \
         Promise.resolve(1); 1}" );
    ( "unreachable conditional await",
      yes "require-await"
        "let run = async () => if false {await Promise.resolve(1)} else {1}" );
    ( "reachable true conditional await",
      no "require-await"
        "let run = async () => if true {await Promise.resolve(1)} else {1}" );
    ( "unreachable while await",
      yes "require-await"
        "let run = async () => {while false {await Promise.resolve()}; 1}" );
    ( "awaited stored loop promise",
      no "no-await-in-loop"
        "let run = async (pending: promise<unit>) => {for i in 0 to 3 {await \
         pending}}" );
    ( "loop updates are not independent",
      no "no-await-in-loop"
        "let run = async state => {for i in 0 to 3 {state.value = await \
         fetch(i)}}" );
    ( "mutation during initialization",
      yes "no-top-level-side-effect"
        "type state = {mutable value: int}\n\
         let state = {value: 0}\n\
         state.value = 1" );
    ( "assert during initialization",
      yes "no-top-level-side-effect" "assert(true)" );
    ( "deferred local module effect",
      no "no-top-level-side-effect"
        "let initialize = () => {module Inner = {Console.log(\"later\")}; ()}"
    );
    ( "recursive eta excluded",
      no "eta-reduction" "let rec loop = value => loop(value)" );
    ( "typed eta narrowing excluded",
      no "eta-reduction"
        "let identity = x => x\n\
         let stringIdentity = (value: string) => identity(value)" );
    ( "record float field",
      yes "no-float-equality"
        "type state = {value: float}\n\
         let same = (left: state, right: state) => left.value == right.value" );
    ( "computed floats",
      yes "no-float-equality"
        "let same = (left: float, right: float) => (left +. 1.0) == (right *. \
         2.0)" );
    ( "array get preserves element type",
      yes "no-float-equality"
        "let same = (xs: array<float>, expected: float) => Array.getUnsafe(xs, \
         0) == expected" );
    ( "option pattern preserves payload",
      yes "no-float-equality"
        "let same = (value: option<float>, expected: float) => switch value {| \
         Some(actual) => actual == expected | None => false}" );
    ( "result pattern preserves payload",
      yes "no-float-equality"
        "let same = (value: result<float, string>, expected: float) => switch \
         value {| Ok(actual) => actual == expected | Error(_) => false}" );
    ( "array initializer result type",
      yes "no-unintended-shallow-equality"
        "let value = Array.fromInitializer(~length=3, i => i)\n\
         let same = value === []" );
    ( "array filter result type",
      yes "no-unintended-shallow-equality"
        "let value = Array.filter([1], _ => true)\nlet same = value === []" );
    ( "array flatMap result type",
      yes "no-unintended-shallow-equality"
        "let value = Array.flatMap([1], i => [i])\nlet same = value === []" );
    ( "array concat result type",
      yes "no-unintended-shallow-equality"
        "let value = Array.concat([1], [2])\nlet same = value === []" );
    ( "list map result type",
      yes "no-unintended-shallow-equality"
        "let value = List.map(list{1}, i => i)\nlet same = value === list{2}" );
    ( "list filter result type",
      yes "no-unintended-shallow-equality"
        "let value = List.filter(list{1}, _ => true)\n\
         let same = value === list{2}" );
    ( "list concat result type",
      yes "no-unintended-shallow-equality"
        "let value = List.concat(list{1}, list{2})\n\
         let same = value === list{2}" );
    ( "boolean API result",
      yes "no-self-compare"
        "let value = Array.isEmpty([])\nlet same = value == value" );
    ( "option array get result",
      no "no-ignored-result" "let run = () => ignore(Array.get([1], 0))" );
    ( "list head result",
      no "no-ignored-result" "let run = () => ignore(List.head(list{1}))" );
    ( "global Function constructor",
      yes "no-dynamic-code"
        "@new external compile: string => (unit => int) = \"Function\"\n\
         let run = code => compile(code)" );
  ]

let partial_checks =
  List.map
    (fun api ->
      ( "partial inventory " ^ api,
        yes "no-partial-function" ("let read = value => " ^ api ^ "(value)") ))
    [
      "List.headExn";
      "List.tailExn";
      "List.tailOrThrow";
      "Option.getExn";
      "Option.getOrThrow";
      "Result.getOrThrow";
    ]

let comparison_checks =
  List.map
    (fun operator ->
      ( "empty operator " ^ operator,
        yes "prefer-empty-check"
          ("let empty = xs => Array.length(xs) " ^ operator ^ " 0") ))
    [ "==="; "!=="; "<="; ">" ]

let constraint_metadata_checks =
  [
    ( "constrained module preserves declared deprecation",
      deprecated_constraint
        "module Api: {@deprecated(\"Use modern\") let old: int => int} = {let \
         old = x => x}\n\
         Api.old(1)"
        "Api.old" );
    ( "nested constrained module preserves declared deprecation",
      deprecated_constraint
        "module Api: {module Nested: {@deprecated(\"Use modern\") let old: int \
         => int}} = {module Nested = {let old = x => x}}\n\
         Api.Nested.old(1)"
        "Api.Nested.old" );
  ]

let () =
  let failures =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error message -> Some (name ^ ": " ^ message))
      (checks @ additional_checks @ partial_checks @ comparison_checks
     @ constraint_metadata_checks)
  in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
