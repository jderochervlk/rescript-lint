open Rescript_linter

let check ?(kind = Source.Implementation)
    ?(context = Semantic_model.default_context) ?(max_lines = 300)
    ?(max_switch_cases = 10) ?expected_range id count text =
  let source =
    Source.
      {
        filename = (if kind = Interface then "Policy.resi" else "Policy.res");
        text;
        kind;
      }
  in
  Result.bind
    (Parser.parse source |> Result.map_error Lint_error.render)
    (fun tree ->
      let findings =
        Syntax_policy_rules.check ~max_lines ~max_switch_cases ~source tree
        @ Idiom_rules.check ~context ~source tree
      in
      let selected =
        List.filter (fun (finding : Diagnostic.t) -> finding.rule = id) findings
      in
      if
        List.length selected = count
        && List.for_all
             (fun (finding : Diagnostic.t) ->
               finding.fixes = []
               && finding.range.start.byte_offset >= 0
               && finding.range.finish.byte_offset <= String.length text
               && Option.fold ~none:true
                    ~some:(fun range -> finding.range = range)
                    expected_range)
             selected
      then Ok ()
      else
        Error
          (Printf.sprintf "%s expected %d, got %d: %s" id count
             (List.length selected) text))

let cases =
  [
    ( "no-obj-external",
      "@obj external make: (~name: string) => 'a = \"\"",
      "@val external make: string => int = \"make\"" );
    ( "no-mutable-record-field",
      "type state = {mutable count: int}",
      "type state = {count: int}" );
    ( "no-record-mutation",
      "let update = state => {state.count = 2}",
      "let update = state => {...state, count: 2}" );
    ("no-while", "while ready {work()}", "let value = work()");
    ( "no-for",
      "for index in 0 to 2 {work(index)}",
      "let value = [1, 2]->Array.map(work)" );
    ("no-empty-loop", "while ready {()}", "while ready {work()}");
    ( "no-negated-condition",
      "let value = if !ready {1} else {2}",
      "let value = if ready {1} else {2}" );
    ( "no-nested-ternary",
      "let value = a ? (b ? 1 : 2) : 3",
      "let value = a ? 1 : 2" );
    ( "prefer-if",
      "let value = switch ready {| true => 1 | false => 2}",
      "let value = switch ready {| Some(x) => x | None => 2}" );
    ( "no-single-case-switch",
      "let value = switch input {| x => work(x)}",
      "let value = switch input {| Some(x) => work(x)}" );
    ( "no-unnecessary-template",
      "let value = `hello`",
      "let value = `hello ${name}`" );
    ( "no-optional-some",
      "let value = consume(~name=?Some(compute()), ())",
      "let value = consume(~name=?maybe, ())" );
    ( "preferred-type-syntax",
      "type names = Dict.t<string>",
      "type names = dict<string>" );
    ( "no-identity-operation",
      "let identity = (x: int) => x + 0",
      "let identity = (x: int) => x + 2" );
    ( "no-erasing-operation",
      "let erase = (x: int) => x * 0",
      "let erase = (x: int) => x * 2" );
    ( "no-modulo-one",
      "let modulo = (x: int) => mod(x, 1)",
      "let modulo = (x: int) => mod(x, 2)" );
  ]

let checks =
  List.concat_map
    (fun (id, bad, good) ->
      [
        (id ^ " positive", check id 1 bad);
        (id ^ " negative", check id 0 good);
        (id ^ " nested", check id 1 ("module Nested = {" ^ bad ^ "}"));
      ])
    cases
  @ [
      ("empty file", check ~max_lines:0 "max-lines" 0 "");
      ( "lines",
        check ~max_lines:1
          ~expected_range:
            Diagnostic.
              {
                start = { line = 1; column = 1; byte_offset = 0 };
                finish = { line = 1; column = 1; byte_offset = 0 };
              }
          "max-lines" 1 "// one\nlet value = 1\n" );
      ( "line boundary",
        check ~max_lines:2 "max-lines" 0 "// one\nlet value = 1\n" );
      ("CRLF", check ~max_lines:1 "max-lines" 1 "// one\r\nlet value = 1\r\n");
      ( "last unterminated line",
        check ~max_lines:1 "max-lines" 1 "// one\nlet value = 1" );
      ( "signature lines",
        check ~kind:Interface ~max_lines:0 "max-lines" 1 "let value: int" );
      ( "switch cases",
        check ~max_switch_cases:1 "max-switch-cases" 1
          "switch value {| Some(x) => x | None => 0}" );
      ( "switch boundary",
        check ~max_switch_cases:2 "max-switch-cases" 0
          "switch value {| Some(x) => x | None => 0}" );
      ( "or patterns one arm",
        check ~max_switch_cases:1 "max-switch-cases" 0
          "switch value {| A | B => 0}" );
      ( "obj interface",
        check ~kind:Interface "no-obj-external" 1
          "@obj external make: (~name: string) => 'a = \"\"" );
      ( "mutable interface",
        check ~kind:Interface "no-mutable-record-field" 1
          "type state = {mutable count: int}" );
      ( "multiple mutable fields",
        check "no-mutable-record-field" 2
          "type state = {mutable a: int, mutable b: int}" );
      ("empty for", check "no-empty-loop" 1 "for i in 2 downto 0 {()}");
      ( "annotated empty loop",
        check "no-empty-loop" 1 "while ready {((): unit)}" );
      ("effectful loop", check "no-empty-loop" 0 "while ready {work(); ()}");
      ("no else", check "no-negated-condition" 0 "if !ready {work()}");
      ( "named not shadow",
        check "no-negated-condition" 0
          "let not = x => x\nlet value = if not(ready) {1} else {2}" );
      ( "negated ternary",
        check "no-negated-condition" 1 "let value = !ready ? 1 : 2" );
      ( "nested alternative",
        check "no-nested-ternary" 1 "let value = a ? 1 : b ? 2 : 3" );
      ( "nested condition",
        check "no-nested-ternary" 1 "let value = (a ? b : c) ? 1 : 2" );
      ( "nested if not ternary",
        check "no-nested-ternary" 0
          "let value = if a {if b {1} else {2}} else {3}" );
      ( "boolean reverse switch",
        check "prefer-if" 1 "switch ready {| false => 1 | true => 2}" );
      ( "boolean guard",
        check "prefer-if" 0 "switch ready {| true if another => 1 | false => 2}"
      );
      ( "boolean duplicate",
        check "prefer-if" 0 "switch ready {| true => 1 | true => 2}" );
      ( "wildcard switch",
        check "no-single-case-switch" 1 "switch work() {| _ => 1}" );
      ( "guarded switch",
        check "no-single-case-switch" 0 "switch input {| x if ready => work(x)}"
      );
      ("empty template", check "no-unnecessary-template" 1 "let value = ``");
      ( "multiline template",
        check "no-unnecessary-template" 1 "let value = `a\nb`" );
      ( "tagged template",
        check "no-unnecessary-template" 0 "let value = tag`hello`" );
      ( "json template",
        check "no-unnecessary-template" 0 "let value = json`{\"a\":1}`" );
      ( "ordinary string",
        check "no-unnecessary-template" 0 "let value = \"hello\"" );
      ( "two interpolations",
        check "no-unnecessary-template" 0 "let value = `${a} ${b}`" );
      ( "optional None",
        check "no-optional-some" 0 "let value = consume(~name=?None, ())" );
      ( "Some mandatory",
        check "no-optional-some" 0 "let value = consume(~name=Some(1), ())" );
      ( "Some shadow",
        check "no-optional-some" 0
          "type custom = Some(int)\nlet value = consume(~name=?Some(1), ())" );
      ( "unknown open Some",
        check "no-optional-some" 0
          "open Other\nlet value = consume(~name=?Some(1), ())" );
      ( "two optional arguments",
        check "no-optional-some" 2
          "let value = consume(~a=?Some(1), ~b=?Some(2), ())" );
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
        check "preferred-type-syntax" 1
          "module D = Dict\ntype values = D.t<int>" );
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
        check "preferred-type-syntax" 0 "open Other\ntype values = Dict.t<int>"
      );
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
      ("unknown integer", check "no-identity-operation" 0 "let f = x => x + 0");
      ( "float identity excluded",
        check "no-identity-operation" 0 "let f = (x: float) => x +. 0.0" );
      ( "float erasing excluded",
        check "no-erasing-operation" 0 "let f = (x: float) => x *. 0.0" );
      ( "mod shadow",
        check "no-modulo-one" 0
          "let mod = (x, y) => x + y\nlet f = (x: int) => mod(x, 1)" );
      ( "qualified custom modulo",
        check "no-modulo-one" 0 "let f = (x: int) => Other.mod(x, 1)" );
      ("mod negative", check "no-modulo-one" 1 "let f = (x: int) => mod(x, -1)");
      ("mod operator", check "no-modulo-one" 1 "let f = (x: int) => x % 1");
      ( "attribute payload ignored",
        check "no-identity-operation" 0 "@example(1 + 0) let value = 1" );
    ]
  @ List.map
      (fun text ->
        (text, check "no-identity-operation" 1 ("let f = (x: int) => " ^ text)))
      [ "0 + x"; "x - 0"; "x * 1"; "1 * x"; "x / 1" ]

let project_dict_shadow =
  let source =
    Source.
      {
        filename = "Dict.resi";
        kind = Interface;
        text = "type t<'a> = array<'a>";
      }
  in
  Result.bind
    (Parser.parse source |> Result.map_error Lint_error.render)
    (function
      | Parser.Interface signature ->
          let context =
            {
              Semantic_model.default_context with
              project_modules = [ "Dict" ];
              module_signatures = [ ("Dict", signature) ];
            }
          in
          check ~context "preferred-type-syntax" 0 "type values = Dict.t<int>"
      | _ -> Error "Expected interface")

let range_check =
  let text = "// \240\159\152\128\nlet value: Dict.t<int> = dict{}" in
  let source =
    Source.{ filename = "Unicode.res"; kind = Implementation; text }
  in
  Result.bind
    (Parser.parse source |> Result.map_error Lint_error.render)
    (fun tree ->
      match
        Idiom_rules.check ~context:Semantic_model.default_context ~source tree
      with
      | [ finding ] when finding.range.start.line = 2 ->
          let start = finding.range.start.byte_offset in
          let length = finding.range.finish.byte_offset - start in
          if String.sub text start length = "Dict.t" then Ok ()
          else Error "Wrong type range"
      | _ -> Error "Missing Unicode type finding")

let integration =
  let id = "no-optional-some" in
  let text =
    "let consume = (~value=?, ()) => value\n\
     let value = consume(~value=?Some(1), ())"
  in
  let source =
    Source.{ filename = "Integration.res"; kind = Implementation; text }
  in
  Result.bind (Rule_config.set Rule_config.default ~id ~enabled:true)
    (fun config ->
      let findings source =
        Linter.lint_source_with_rules config source
        |> Result.map_error Lint_error.render
      in
      Result.bind (findings source) (function
        | [ finding ] when finding.rule = id ->
            let text =
              "// rescript-lint-disable no-optional-some -- explicit adapter\n"
              ^ text ^ "\n// rescript-lint-enable no-optional-some\n"
            in
            Result.bind
              (findings { source with text })
              (fun findings ->
                if findings = [] then Ok () else Error "Suppression not honored")
        | _ -> Error "Rule not integrated"))

let extra_checks =
  [
    ( "module type constraint",
      check "preferred-type-syntax" 1
        "module type Values = {type t} with type t = Dict.t<int>" );
    ( "signature type constraint",
      check ~kind:Interface "preferred-type-syntax" 1
        "module Values: {type t} with type t = Dict.t<int>" );
    ("project Dict shadows runtime", project_dict_shadow);
    ("Unicode diagnostic range", range_check);
    ("linter and suppressions", integration);
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

let () =
  let failures =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
      (checks @ extra_checks)
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
