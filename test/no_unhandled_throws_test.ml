open Rescript_linter

let source ?(kind = Source.Implementation) text =
  Source.{ filename = "throws.res"; text; kind }

let declaration = "@throws(Not_found)\nlet read = () => 0\n\n"

let named =
  "exception A\nexception B(int)\n\n@throws([A, B])\nlet read = () => 0\n"

let bare = "@throws @val external read: unit => int = \"read\"\n\n"

let check ?kind expected text =
  match Linter.lint_source (source ?kind text) with
  | Error error -> Error (Lint_error.render error)
  | Ok diagnostics ->
      let actual = List.map (fun (d : Diagnostic.t) -> d.rule) diagnostics in
      if actual = expected then Ok ()
      else
        Error
          ("Unexpected diagnostics for " ^ text ^ ": "
          ^ String.concat "; " (List.map Diagnostic.render diagnostics))

let count n = check (List.init n (fun _ -> "no-unhandled-throws"))
let clean = count 0
let banned = count 1

let unsupported ?kind text =
  match Linter.lint_source (source ?kind text) with
  | Error (Lint_error.Analysis_errors (first, _))
    when first.rule = "throws-analysis" ->
      Ok ()
  | Error error -> Error (Lint_error.render error)
  | Ok diagnostics ->
      Error
        ("Expected analysis failure, got "
        ^ String.concat "; " (List.map Diagnostic.render diagnostics))

let checks =
  [
    ("unhandled", banned (declaration ^ "read()"));
    ("declaration alone", clean declaration);
    ("try", clean (declaration ^ "try read() catch {| Not_found => 0}"));
    ( "switch",
      clean
        (declaration
       ^ "switch read() {| value => Ok(value) | exception Not_found => \
          Error(#Missing)}") );
    ( "result switch not a catch",
      banned (declaration ^ "switch read() {| Ok(v) => v | Error(_) => 0}") );
    ( "caller annotation",
      banned (declaration ^ "@throws(Not_found)\nlet caller = () => read()") );
    ( "suppression on result ignored",
      banned (declaration ^ "@doesNotThrow read()") );
    ( "suppression on function ignored",
      banned (declaration ^ "(@doesNotThrow read)()") );
    ("legacy", banned "@raises(Not_found)\nlet read = () => 0\nread()");
    ("unknown exception bare annotation", banned (bare ^ "read()"));
    ("bare catchall", clean (bare ^ "try read() catch {| _ => 0}"));
    ("bare variable catchall", clean (bare ^ "try read() catch {| error => 0}"));
    ( "bare named catch insufficient",
      banned (bare ^ "try read() catch {| JsExn(_) => 0}") );
    ( "bare switch catchall",
      clean (bare ^ "switch read() {| value => value | exception _ => 0}") );
    ( "legacy bare",
      banned "@raises @val external read: unit => int = \"read\"\n\nread()" );
    ( "multiple exceptions",
      clean (named ^ "try read() catch {| A => 0 | B(_) => 0}") );
    ( "wrong exception",
      banned (declaration ^ "try read() catch {| Failure(_) => 0}") );
    ("missing one exception", banned (named ^ "try read() catch {| A => 0}"));
    ( "payload-specific catch",
      banned (named ^ "try read() catch {| A => 0 | B(1) => 0}") );
    ( "payload variable catch",
      clean (named ^ "try read() catch {| A => 0 | B(value) => value}") );
    ( "payload tuple catch",
      clean
        "exception E(int, string)\n\n\
         @throws(E)\n\
         let read = () => 0\n\
         try read() catch {| E(_, _) => 0}" );
    ( "payload tuple partial",
      banned
        "exception E(int, string)\n\n\
         @throws(E)\n\
         let read = () => 0\n\
         try read() catch {| E(_, \"x\") => 0}" );
    ("or catches", clean (named ^ "try read() catch {| A | B(_) => 0}"));
    ( "guard insufficient",
      banned (declaration ^ "try read() catch {| Not_found if flag => 0}") );
    ( "guard fallback",
      clean
        (declaration
       ^ "try read() catch {| Not_found if flag => 0 | Not_found => 0}") );
    ( "guarded catchall",
      banned (declaration ^ "try read() catch {| _ if flag => 0}") );
    ( "nested handler union",
      clean (named ^ "try {try read() catch {| A => 0}} catch {| B(_) => 0}") );
    ("catch body", banned (declaration ^ "try 0 catch {| _ => read()}"));
    ( "catch guard",
      banned (declaration ^ "try 0 catch {| _ if read() == 0 => 0}") );
    ( "result arm",
      banned (declaration ^ "switch 0 {| value => read() | exception _ => 0}")
    );
    ( "exception arm",
      banned
        (declaration ^ "switch 0 {| value => value | exception _ => read()}") );
    ( "switch guard",
      banned
        (declaration
       ^ "switch 0 {| value if read() == 0 => value | exception _ => 0}") );
    ( "nested outer protects handler",
      clean
        (declaration
       ^ "try {try 0 catch {| _ => read()}} catch {| Not_found => 0}") );
    ( "callback creation",
      banned
        (declaration
       ^ "try {let callback = () => read(); callback} catch {| _ => () => 0}")
    );
    ( "callback own handler",
      clean (declaration ^ "let callback = () => try read() catch {| _ => 0}")
    );
    ( "multiple parameters",
      banned
        (declaration
       ^ "try {let callback = (a, b) => read(); callback} catch {| _ => (a, b) \
          => 0}") );
    ( "default parameter",
      banned (declaration ^ "let callback = (~value=read()) => value") );
    ( "returned function resets handlers",
      banned
        (declaration
       ^ "let callback = () => try (() => read()) catch {| _ => () => 0}") );
    ("alias", banned (declaration ^ "let fetch = read\nfetch()"));
    ( "alias handled",
      clean
        (declaration ^ "let fetch = read\ntry fetch() catch {| Not_found => 0}")
    );
    ( "alias chain",
      banned (declaration ^ "let fetch = read\nlet get = fetch\nget()") );
    ( "alias capture survives shadow",
      banned (declaration ^ "let fetch = read\nlet read = () => 0\nfetch()") );
    ("value shadow", clean (declaration ^ "let read = () => 0\nread()"));
    ("parameter shadow", clean (declaration ^ "let caller = read => read()"));
    ( "destructured parameter shadow",
      clean (declaration ^ "let caller = ({read}) => read()") );
    ( "case pattern shadow",
      clean (declaration ^ "switch value {| Some(read) => read() | _ => 0}") );
    ("initializer sees old binding", banned (declaration ^ "let read = read()"));
    ( "recursive call",
      banned "@throws(Not_found)\nlet rec read = () => read()\n" );
    ( "recursive call handled",
      clean
        "@throws(Not_found)\nlet rec read = () => try read() catch {| _ => 0}\n"
    );
    ("pipe", banned "@throws(Not_found)\nlet read = x => x\n0->read");
    ( "pipe application once",
      banned "@throws(Not_found)\nlet read = (x, y) => x\n0->read(1)" );
    ( "pipe handler",
      clean
        "@throws(Not_found)\nlet read = x => x\ntry 0->read catch {| _ => 0}" );
    ("constrained callee", banned (declaration ^ "(read: unit => int)()"));
    ("local module", banned ("module Api = {" ^ declaration ^ "}\nApi.read()"));
    ( "module alias",
      banned
        ("module Api = {" ^ declaration ^ "}\nmodule Alias = Api\nAlias.read()")
    );
    ( "qualified local exception",
      clean
        "module Api = {exception Missing\n\n\
         @throws(Missing)\n\
         let read = () => 0}\n\
         try Api.read() catch {| Api.Missing => 0}" );
    ( "module exception alias identity",
      clean
        "module Api = {exception Missing\n\n\
         @throws(Missing)\n\
         let read = () => 0}\n\
         module Alias = Api\n\
         try Api.read() catch {| Alias.Missing => 0}" );
    ( "exception shadow",
      banned
        "exception E\n\n\
         @throws(E)\n\
         let read = () => 0\n\
         exception E\n\
         try read() catch {| E => 0}" );
    ( "exception alias",
      clean
        "exception E\n\n\
         @throws(E)\n\
         let read = () => 0\n\
         exception Alias = E\n\
         try read() catch {| Alias => 0}" );
    ( "exception closure identity",
      clean
        "exception E\n\n\
         @throws(E)\n\
         let read = () => 0\n\
         let caller = () => try read() catch {| E => 0}\n\
         exception E\n\
         caller()" );
    ( "module shadow identity",
      banned
        "module Api = {exception E\n\n\
         @throws(E)\n\
         let read = () => 0}\n\
         let fetch = Api.read\n\
         module Api = {exception E}\n\
         try fetch() catch {| Api.E => 0}" );
    ( "local open",
      banned ("module Api = {" ^ declaration ^ "}\nopen Api\nread()") );
    ( "include",
      banned ("module Api = {" ^ declaration ^ "}\ninclude Api\nread()") );
    ( "block module",
      banned
        (declaration
       ^ "let caller = () => {module Api = {let fetch = read}; Api.fetch()}") );
    ( "module initializer under handler",
      clean
        (declaration
       ^ "try {module Api = {let result = read()}; Api.result} catch {| _ => 0}"
        ) );
    ("alias reference alone", clean (declaration ^ "let fetch = read"));
    ( "qualified alias",
      banned
        ("module Api = {" ^ declaration ^ "}\nlet fetch = Api.read\nfetch()") );
    ( "sync external",
      banned
        "@throws(Not_found) @val external read: unit => int = \"read\"\n\n\
         read()" );
    ( "interface annotation",
      check ~kind:Source.Interface []
        "@throws(Not_found)\nlet read: unit => int" );
    ( "interface local exception",
      check ~kind:Source.Interface []
        "exception Missing\n\n@throws(Missing)\nlet read: unit => int" );
    ( "nonfunction shadow type",
      banned
        "@throws(Not_found)\n\
         let read = () => 0\n\
         type unrelated = Not_found\n\
         try read() catch {| Not_found => 0}" );
    ( "duplicate annotation union",
      clean
        "exception A\n\
         exception B\n\n\
         @throws(A) @raises(B)\n\
         let read = () => 0\n\
         try read() catch {| A | B => 0}" );
    ( "bare dominates named",
      banned
        "@throws(Not_found) @raises\n\
         let read = () => 0\n\
         try read() catch {| Not_found => 0}" );
    ( "strings and metadata opaque",
      clean
        "// @throws(Not_found)\n\
         let text = \"@throws read()\"\n\n\
         @deprecated({migrate: read()})\n\
         let value = 0" );
    ("unknown files are outside local contract", clean "Remote.read()");
    ("missing callee metadata", unsupported (declaration ^ "Remote.read()"));
    ( "missing exception metadata",
      unsupported "@throws(Remote.E)\nlet read = () => 0" );
    ("unknown open", unsupported (declaration ^ "open Remote\nread()"));
    ("escape to callback argument", unsupported (declaration ^ "consume(read)"));
    ("escape in tuple", unsupported (declaration ^ "let pair = (read, 0)"));
    ( "partial application",
      unsupported "@throws(Not_found)\nlet read = (a, b) => 0\nread(0, ...)" );
    ( "async annotated function",
      unsupported "@throws(Not_found)\nlet read = async () => 0" );
    ( "await",
      unsupported
        (declaration
       ^ "let caller = async () => try await read() catch {| _ => 0}") );
    ( "promise external",
      unsupported "@throws @val external read: unit => promise<int> = \"read\""
    );
    ( "higher order external",
      unsupported "@throws @val external read: unit => (unit => int) = \"read\""
    );
    ( "annotated alias",
      unsupported (declaration ^ "@throws(Failure)\nlet fetch = read") );
    ("nonfunction annotation", unsupported "@throws(Not_found)\nlet value = 0");
    ("malformed payload", unsupported "@throws(42)\nlet read = () => 0");
    ("empty list payload", unsupported "@throws([])\nlet read = () => 0");
    ( "computed payload",
      unsupported "@throws(getException())\nlet read = () => 0" );
    ( "string payload explicitly unsupported",
      unsupported "@throws(\"Not_found\")\nlet read = () => 0" );
    ( "annotation on call",
      unsupported (declaration ^ "@throws(Not_found) read()") );
    ( "nested interface module explicitly unsupported",
      unsupported ~kind:Source.Interface
        "module Api: {@throws(Not_found) let read: unit => int}" );
    ( "constrained module signature is authoritative",
      check []
        "module Api: {let read: unit => int} = {@throws(Not_found) let read = \
         () => 0}\n\
         Api.read()" );
  ]

let boundary_checks =
  [
    ( "expression local open",
      banned
        ("module Api = {" ^ declaration
       ^ "}\nlet caller = () => {open Api; read()}") );
    ( "extension expression traversed",
      banned (declaration ^ "let value = %extension(read())") );
    ( "catch alias",
      clean (declaration ^ "try read() catch {| Not_found as error => 0}") );
    ( "catch constraint",
      clean (declaration ^ "try read() catch {| (error: exn) => 0}") );
    ( "unsupported pattern does not cover",
      banned (declaration ^ "try read() catch {| #Missing => 0}") );
    ( "payload alias",
      clean (named ^ "try read() catch {| A => 0 | B(_ as value) => value}") );
    ( "payload constraint",
      clean (named ^ "try read() catch {| A => 0 | B((value: int)) => value}")
    );
    ( "payload or right wildcard",
      clean (named ^ "try read() catch {| A => 0 | B(1 | _) => 0}") );
    ( "payload or left wildcard",
      clean (named ^ "try read() catch {| A => 0 | B(_ | 1) => 0}") );
    ( "nested outer catchall",
      clean
        (declaration
       ^ "try {try read() catch {| Not_found => 0}} catch {| _ => 0}") );
    ( "switch normal alias not catchall",
      banned (declaration ^ "switch read() {| _ as value => value}") );
    ( "switch normal constraint not catchall",
      banned (declaration ^ "switch read() {| (value: int) => value}") );
    ( "constrained binding",
      banned (declaration ^ "let fetch: unit => int = read\nfetch()") );
    ("nonvariant type", clean (declaration ^ "type count = int"));
    ( "local exception",
      clean
        "let caller = () => {exception Missing\n\n\
         @throws(Missing)\n\
         let read = () => 0\n\
         try read() catch {| Missing => 0}}" );
    ( "locally abstract type",
      banned
        "@throws(Not_found)\nlet read = (type a, value: a) => value\nread(0)" );
    ( "loop visits bounds and body",
      count 3 (declaration ^ "for i in read() to read() {read()}") );
    ( "module exports exclude outer values",
      unsupported (declaration ^ "module Api = {exception E}\nApi.read()") );
    ("unknown reference", unsupported (declaration ^ "let fetch = Remote.read"));
    ( "immediate callback is separate scope",
      banned (declaration ^ "try (() => read())() catch {| _ => 0}") );
    ( "external tuple result",
      clean "@throws @val external read: unit => (int, string) = \"read\"" );
    ( "nonfunction external",
      unsupported "@throws @val external value: int = \"value\"" );
    ( "tuple annotation",
      clean
        "exception A\n\
         exception B\n\n\
         @throws((A, B))\n\
         let read = () => 0\n\
         try read() catch {| A | B => 0}" );
    ( "bare then named annotation",
      banned
        "@throws @raises(Not_found)\n\
         let read = () => 0\n\
         try read() catch {| Not_found => 0}" );
    ( "typed annotation payload",
      unsupported "@throws(: int)\nlet read = () => 0" );
    ("file annotation", unsupported "@@throws(Not_found)\nlet read = () => 0");
    ( "expression annotation",
      unsupported (declaration ^ "let caller = () => @throws(Not_found) read()")
    );
    ( "module type",
      check [] (declaration ^ "module type Api = {let read: unit => int}") );
    ("type extension", unsupported (declaration ^ "type exn += E"));
    ( "recursive module",
      unsupported
        "module rec Api: {@throws(Not_found) let read: unit => int} = \
         {@throws(Not_found) let read = () => 0}" );
    ("functor", unsupported (declaration ^ "module F = (X: {}) => {}"));
    ( "signature type",
      check ~kind:Source.Interface []
        "type count = int\n\n@throws(Not_found)\nlet read: unit => count" );
    ( "signature nonthrows attribute",
      check ~kind:Source.Interface []
        "@@deprecated(\"old\")\n\n@throws(Not_found)\nlet read: unit => int" );
    ( "signature module identifier",
      unsupported ~kind:Source.Interface
        "@throws(Not_found)\nlet read: unit => int\nmodule Api: Unknown" );
    ( "signature open",
      unsupported ~kind:Source.Interface
        "@throws(Not_found)\nlet read: unit => int\nopen Unknown" );
    ( "signature include",
      unsupported ~kind:Source.Interface
        "@throws(Not_found)\nlet read: unit => int\ninclude Unknown" );
    ( "signature module type",
      check ~kind:Source.Interface []
        "@throws(Not_found)\nlet read: unit => int\nmodule type Api = {}" );
    ( "signature recursive module",
      unsupported ~kind:Source.Interface
        "@throws(Not_found)\nlet read: unit => int\nmodule rec Api: {}" );
    ( "signature type extension",
      unsupported ~kind:Source.Interface
        "@throws(Not_found)\nlet read: unit => int\ntype exn += E" );
  ]

let expect name value = (name, if value then Ok () else Error name)

let exact_range =
  let prefix = declaration ^ "// comment\n  " in
  match Linter.lint_source (source (prefix ^ "read()")) with
  | Ok [ diagnostic ] ->
      diagnostic
      = Diagnostic.
          {
            filename = "throws.res";
            rule = "no-unhandled-throws";
            fixes = [];
            message =
              "Handle Not_found when calling read. Use try/catch or switch \
               exception patterns; caller annotations do not handle \
               exceptions.";
            range =
              {
                start =
                  { line = 5; column = 3; byte_offset = String.length prefix };
                finish =
                  {
                    line = 5;
                    column = 7;
                    byte_offset = String.length prefix + 4;
                  };
              };
          }
  | _ -> false

let utf8_range =
  let prefix = declaration ^ "let text = \"\195\169\"; " in
  match Linter.lint_source (source (prefix ^ "read()")) with
  | Ok [ diagnostic ] ->
      diagnostic.range.start.column = 18
      && diagnostic.range.start.byte_offset = String.length prefix
      && diagnostic.range.finish.byte_offset = String.length prefix + 4
  | _ -> false

let missing_message =
  match Linter.lint_source (source (named ^ "try read() catch {| A => 0}")) with
  | Ok [ diagnostic ] ->
      diagnostic.message
      = "Handle B when calling read. Use try/catch or switch exception \
         patterns; caller annotations do not handle exceptions."
  | _ -> false

let invalid_source =
  match Linter.lint_source (source (declaration ^ "read()\nlet =")) with
  | Error (Lint_error.Parse_errors _) -> true
  | _ -> false

let () =
  let failures =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
      (checks @ boundary_checks
      @ [
          expect "exact range/message" exact_range;
          expect "UTF-8 range" utf8_range;
          expect "missing exceptions message" missing_message;
          expect "invalid syntax takes precedence" invalid_source;
        ])
  in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
