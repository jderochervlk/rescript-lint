open Rescript_linter

let source ?(kind = Source.Implementation) text =
  Source.{ filename = "hooks.res"; text; kind }

let check ?kind expected text =
  match Linter.lint_source (source ?kind text) with
  | Ok diagnostics ->
      let rules = List.map (fun (d : Diagnostic.t) -> d.rule) diagnostics in
      if rules = expected then Ok ()
      else
        Error
          ("Unexpected diagnostics for " ^ text ^ ": "
          ^ String.concat "; " (List.map Diagnostic.render diagnostics))
  | Error error -> Error (Lint_error.render error)

let hooks count text =
  check (List.init count (fun _ -> "react/rules-of-hooks")) text

let clean = hooks 0
let banned = hooks 1
let component body = "@react.component\nlet make = (~flag) => {" ^ body ^ "}"
let custom body = "let useThing = () => {" ^ body ^ "}"

let checks =
  [
    ("module scope", banned "React.useState(() => 0)");
    ("ordinary function", banned "let read = () => Hooks.useThing()");
    ("unannotated make is ordinary", banned "let make = () => useThing()");
    ("component", clean (component "React.useState(() => 0)"));
    ("custom hook", clean (custom "React.useState(() => 0)"));
    ( "naming boundaries",
      hooks 3
        "use()\nuseA()\nuse1()\nuser()\nuseful()\nuse_Thing()\nu()\nOther.use()"
    );
    ("qualified custom hook", banned "One.Two.useThing()");
    ("reference is not a call", clean "let hook = React.useState");
    ("passing reference", clean "consume(React.useState)");
    ("constrained callee", banned "(useThing: unit => int)()");
    ("pipe reference", banned "0->React.useState");
    ("pipe application once", banned "0->Hooks.useThing(1)");
    ("clean pipe", clean (custom "0->Hooks.useThing"));
    ("conditional pipe", banned (custom "if flag {0->Hooks.useThing} else {0}"));
    ("conditional", banned (component "if flag {useThing()} else {0}"));
    ("both branches", hooks 2 (component "if flag {useA()} else {useB()}"));
    ("ternary", banned (component "flag ? useThing() : 0"));
    ("condition is unconditional", clean (component "if useFlag() {1} else {2}"));
    ( "branch rejoin",
      clean (component "if flag {work()} else {other()}; useThing()") );
    ( "switch scrutinee",
      clean (custom "switch useThing() {| Some(v) => v | None => 0}") );
    ( "switch branches",
      hooks 2 (custom "switch value {| Some(v) => useA(v) | None => useB()}") );
    ( "switch guard",
      banned (custom "switch value {| Some(v) if useFlag(v) => v | _ => 0}") );
    ( "short circuit right",
      hooks 2 (custom "flag && useFlag(); flag || useFlag()") );
    ("short circuit left", clean (custom "useFlag() && flag; useFlag() || flag"));
    ("while", hooks 2 (custom "while useFlag() {useThing()}"));
    ("for", banned (custom "for i in 0 to 4 {useThing(i)}"));
    ("for bounds", clean (custom "for i in useStart() to useEnd() {work(i)}"));
    ("callback", banned (component "items->Array.map(_ => useThing())"));
    ( "event handler",
      banned (component "let onClick = () => useThing(); onClick") );
    ( "effect callback",
      banned (component "React.useEffect(() => {useThing(); None}, [])") );
    ( "initializer callback",
      banned (component "React.useState(() => useThing())") );
    ( "nested custom hook",
      clean (component "let useInner = () => useThing(); useInner()") );
    ( "nested hook resets branch",
      clean
        (component
           "if flag {let useInner = () => useThing(); consume(useInner)}") );
    ( "nested hook call still conditional",
      banned (component "if flag {let useInner = () => useThing(); useInner()}")
    );
    ("multi parameter", clean "let useThing = (a, b, ~c) => useOther(a, b, c)");
    ( "component parameters",
      clean "@react.component\nlet make = (~a, ~b) => useOther(a, b)" );
    ( "returned callback",
      banned "let useThing = (a, b) => (c, d) => useOther(a, b, c, d)" );
    ("default argument", banned "let useThing = (~value=useOther()) => value");
    ( "later default argument",
      banned "let useThing = (a, ~value=useOther()) => value" );
    ( "default callback",
      banned "let useThing = (~value=(() => useOther())) => value" );
    ( "default with clean body",
      banned "let useThing = (~value=useOther()) => useMore(value)" );
    ( "type constrained binding",
      clean "let useThing: (int, int) => int = (a, b) => useOther(a, b)" );
    ("return constraint", clean "let useThing = (a, b): int => useOther(a, b)");
    ( "type parameter",
      clean "let useThing = (type a, value: a) => useOther(value)" );
    ( "try body and handler",
      hooks 2 (custom "try useThing() catch {| _ => useOther()}") );
    ( "exception switch",
      hooks 3
        (custom
           "switch useThing() {| value => useOther(value) | exception _ => \
            useError()}") );
    ( "handler creation not execution",
      clean
        (custom
           "try {let useInner = () => useThing(); consume(useInner)} catch {| \
            _ => ()}") );
    ("after try", clean (custom "try work() catch {| _ => ()}; useThing()"));
    ( "special use conditional and loops",
      clean
        (component "if flag {React.use(promise)}; while flag {use(promise)}") );
    ("special use short circuit", clean (component "flag && React.use(promise)"));
    ( "special use try",
      banned (component "try React.use(promise) catch {| _ => 0}") );
    ( "special use catch",
      banned (component "try work() catch {| _ => React.use(promise)}") );
    ( "special use exception switch",
      hooks 3
        (component
           "switch React.use(promise) {| value => React.use(value) | exception \
            _ => use(promise)}") );
    ( "special use normal switch",
      clean
        (component
           "switch flag {| true => React.use(promise) | false => use(other)}")
    );
    ( "or pattern without exceptions",
      clean (component "switch value {| Some(_) | None => React.use(promise)}")
    );
    ( "aliased switch pattern",
      clean
        (component
           "switch value {| Some(_) as found => React.use(found) | _ => 0}") );
    ( "constrained switch pattern",
      clean (component "switch value {| (v: int) => React.use(v)}") );
    ( "exception alternatives",
      banned
        (component
           "switch value {| exception A | exception B => React.use(promise) | \
            _ => 0}") );
    ( "right exception alternative",
      banned
        (component
           "switch value {| A | exception B => React.use(promise) | _ => 0}") );
    ( "nested special use inside try",
      banned (component "try {if flag {React.use(promise)}} catch {| _ => ()}")
    );
    ( "special use callback",
      banned (component "let later = () => React.use(promise); later") );
    ("async hook", banned "let useThing = async () => useOther()");
    ( "async component",
      banned "@react.component\nlet make = async () => React.use(promise)" );
    ( "nested sync hook",
      clean
        "let useThing = async () => {let useInner = () => useOther(); \
         consume(useInner)}" );
    ( "module initializer resets context",
      banned (component "module Local = {let value = useThing()}; Local.value")
    );
    ( "module custom hook",
      clean "module Local = {let useThing = () => useOther()}" );
    ( "module reset does not escape",
      clean (component "module Local = {let value = 0}; useThing(Local.value)")
    );
    ( "memo component",
      clean
        "@react.component\nlet make = React.memo((~a, ~b) => useThing(a, b))" );
    ( "forward ref",
      clean
        "@react.component\n\
         let make = React.forwardRef((~a, ref) => useThing(a, ref))" );
    ( "nested wrappers",
      clean
        "@react.component\n\
         let make = React.memo(React.forwardRef((~a, ref) => useThing(a, ref)))"
    );
    ( "memo comparator is callback",
      banned
        "@react.component\n\
         let make = React.memo((~a) => useThing(a), (_, _) => useOther())" );
    ( "unknown wrapper",
      banned "@react.component\nlet make = wrap(() => useThing())" );
    ( "attribute does not bless initializer",
      banned "@react.component\nlet make = useThing()" );
    ( "componentWithProps",
      clean "@react.componentWithProps\nlet make = props => useThing(props)" );
    ("jsx component", clean "@jsx.component\nlet make = () => useThing()");
    ( "tuple binding is not a custom hook",
      banned "let (useThing, other) = (() => useOther(), 0)" );
    ("JSX event", banned (component "<button onClick={_ => useThing()} />"));
    ("JSX child", clean (component "<div>{useThing()}</div>"));
    ( "literals and metadata",
      clean
        "// useThing()\n\
         let text = \"useOther()\"\n\n\
         @deprecated({migrate: useThing()})\n\
         let value = 0" );
    ( "interface",
      check ~kind:Source.Interface []
        "@react.component\n\
         let make: unit => React.element\n\
         let useThing: unit => int" );
    ( "mixed rule ordering",
      check
        [
          "no-console";
          "react/rules-of-hooks";
          "no-object-magic";
          "react/rules-of-hooks";
          "no-unsafe";
        ]
        "Console.log(useThing(Obj.magic(useOther(Option.getUnsafe(None)))))" );
  ]

let expect name passed = (name, if passed then Ok () else Error name)

let functor_path =
  let identifier =
    Longident.Ldot (Lapply (Lident "F", Lident "X"), "useThing")
  in
  let callee = Ast_helper.Exp.ident (Location.mknoloc identifier) in
  let expression = Ast_helper.Exp.apply callee [] in
  let tree = Parser.Implementation [ Ast_helper.Str.eval expression ] in
  Rules_of_hooks.check ~source:(source "") tree = []

let exact_range =
  match
    Linter.lint_source (source "// comment\n  React.useState(() => 0)\n")
  with
  | Ok [ diagnostic ] ->
      diagnostic
      = Diagnostic.
          {
            filename = "hooks.res";
            rule = "react/rules-of-hooks";
            fixes = [];
            message =
              "Call hooks only at the top level of a React component or custom \
               hook.";
            range =
              {
                start = { line = 2; column = 3; byte_offset = 13 };
                finish = { line = 2; column = 17; byte_offset = 27 };
              };
          }
  | _ -> false

let utf8_range =
  match
    Linter.lint_source (source "let text = \"\195\169\"; React.use(text)")
  with
  | Ok [ diagnostic ] ->
      diagnostic.range.start.column = 18
      && diagnostic.range.start.byte_offset = 17
      && diagnostic.range.finish.column = 27
      && diagnostic.range.finish.byte_offset = 26
  | _ -> false

let invalid_source =
  match Linter.lint_source (source "useThing()\nlet =") with
  | Error (Lint_error.Parse_errors _) -> true
  | _ -> false

let message expected text =
  match Linter.lint_source (source text) with
  | Ok [ diagnostic ] -> diagnostic.message = expected
  | _ -> false

let message_checks =
  List.map
    (fun (name, expected, text) -> expect name (message expected text))
    [
      ( "conditional message",
        "Do not call hooks conditionally.",
        custom "if flag {useThing()}" );
      ( "loop message",
        "Do not call hooks in loops.",
        custom "while flag {useThing()}" );
      ( "handler message",
        "Do not call hooks in try/catch or exception-handling switches.",
        custom "try useThing() catch {| _ => 0}" );
      ( "default message",
        "Do not call hooks in default arguments. Move the call into the \
         function body.",
        "let useThing = (~value=useOther()) => value" );
      ( "async message",
        "Do not call hooks in async functions.",
        "let useThing = async () => useOther()" );
    ]

let () =
  let failures =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
      (checks @ message_checks
      @ [
          expect "exact range" exact_range;
          expect "UTF-8 range" utf8_range;
          expect "invalid syntax" invalid_source;
          expect "unresolved functor path" functor_path;
        ])
  in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
