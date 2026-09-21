open Rescript_linter

let source ?(kind = Source.Implementation) text =
  Source.{ filename = "exceptions.res"; text; kind }

let diagnostics ?kind text =
  let source = source ?kind text in
  Result.map (Exception_rules.check ~source) (Parser.parse source)

let check ?kind expected text =
  match diagnostics ?kind text with
  | Error error -> Error (Lint_error.render error)
  | Ok actual ->
      let rules = List.map (fun (value : Diagnostic.t) -> value.rule) actual in
      if rules = expected then Ok ()
      else
        Error
          (Printf.sprintf "Expected [%s], got [%s] for %s"
             (String.concat "; " expected)
             (String.concat "; " rules) text)

let clean = check []
let useless = check [ "no-useless-catch" ]
let catch_all = check [ "no-catch-all-exception" ]
let debugger = check [ "no-debugger" ]

let exact_range rule text first last =
  match diagnostics text with
  | Ok [ diagnostic ]
    when diagnostic.rule = rule
         && diagnostic.range.start.byte_offset = first
         && diagnostic.range.finish.byte_offset = last
         && diagnostic.filename = "exceptions.res"
         && diagnostic.fixes = [] ->
      Ok ()
  | _ -> Error "diagnostic range or metadata mismatch"

let checks =
  [
    ("debugger", debugger "let inspect = () => {%debugger; value}");
    ( "debugger in nested module",
      debugger "module M = {let f = () => %debugger}" );
    ("debugger string", clean "let text = \"%debugger\"");
    ("debugger comment", clean "// %debugger\nlet x = 1");
    ("other extension", clean "let value = %raw(\"1\")");
    ("attribute payload", clean "@example(%debugger) let value = 1");
    ("standalone attribute payload", clean "@@example(%debugger)\nlet value = 1");
    ("debugger attribute is not executable", clean "@debugger let value = 1");
    ("interface", check ~kind:Source.Interface [] "let value: int");
    ( "interface attribute payload",
      check ~kind:Source.Interface [] "@example(%debugger) let value: int" );
    ( "standalone interface attribute payload",
      check ~kind:Source.Interface [] "@@example(%debugger)\nlet value: int" );
    ( "immediate rethrow",
      useless "try {read()} catch {| caught => throw(caught)}" );
    ("legacy raise", useless "try {read()} catch {| caught => raise(caught)}");
    ( "qualified throw",
      useless "try {read()} catch {| caught => Pervasives.throw(caught)}" );
    ( "qualified raise",
      useless "try {read()} catch {| caught => Pervasives.raise(caught)}" );
    ( "constrained argument",
      useless "try {read()} catch {| caught => throw((caught: exn))}" );
    ( "constrained body",
      useless "try {read()} catch {| caught => (throw(caught): int)}" );
    ( "aliased constructor",
      useless "try {read()} catch {| Not_found as caught => throw(caught)}" );
    ( "aliased wildcard",
      useless "try {read()} catch {| _ as caught => throw(caught)}" );
    ( "constrained caught pattern",
      useless "try {read()} catch {| (caught: exn) => throw(caught)}" );
    ( "or-pattern rethrow",
      useless
        "try {read()} catch {| (Not_found as caught) | (Failure(_) as caught) \
         => throw(caught)}" );
    ( "or-pattern catch-all",
      catch_all "try {read()} catch {| Not_found | _ => 0}" );
    ( "multiple rethrows",
      useless
        "try {read()} catch {| Not_found as first => throw(first) | other => \
         throw(other)}" );
    ( "one handled arm",
      clean "try {read()} catch {| Not_found => 0 | caught => throw(caught)}" );
    ( "guarded rethrow",
      clean "try {read()} catch {| caught if log(caught) => throw(caught)}" );
    ("guarded swallow", clean "try {read()} catch {| _ if enabled => 0}");
    ("wildcard catch", catch_all "try {read()} catch {| _ => 0}");
    ("variable catch", catch_all "try {read()} catch {| caught => log(caught)}");
    ( "aliased wildcard catch",
      catch_all "try {read()} catch {| _ as caught => log(caught)}" );
    ( "changed exception",
      catch_all "try {read()} catch {| caught => throw(Failure(\"changed\"))}"
    );
    ("wrong variable", catch_all "try {read()} catch {| caught => throw(other)}");
    ( "qualified variable",
      catch_all "try {read()} catch {| caught => throw(M.caught)}" );
    ( "constructor payload is not the original exception",
      clean "try {read()} catch {| Failure(caught) => throw(caught)}" );
    ( "constructor reconstruction conservative",
      clean "try {read()} catch {| Not_found => throw(Not_found)}" );
    ( "logging before rethrow",
      catch_all "try {read()} catch {| caught => {log(caught); throw(caught)}}"
    );
    ( "rebound caught variable",
      catch_all
        "try {read()} catch {| caught => {let caught = other; throw(caught)}}"
    );
    ( "function body is not immediate",
      catch_all "try {read()} catch {| caught => () => throw(caught)}" );
    ("ordinary switch", clean "switch value {| _ => 0}");
    ( "switch exception catch",
      catch_all "switch read() {| exception _ => 0 | value => value}" );
    ( "switch exception rethrow",
      clean
        "switch read() {| exception caught => throw(caught) | value => value}"
    );
    ( "switch exception alias rethrow",
      clean
        "switch read() {| (exception _) as caught => throw(caught) | value => \
         value}" );
    ( "switch exception constrained rethrow",
      clean
        "switch read() {| (exception caught: exn) => throw(caught) | value => \
         value}" );
    ( "switch exception or-pattern",
      catch_all
        "switch read() {| exception Not_found | exception _ => 0 | value => \
         value}" );
    ( "switch specific exception",
      clean "switch read() {| exception Not_found => 0 | value => value}" );
    ( "switch exception guard",
      clean
        "switch read() {| exception caught if enabled => 0 | value => value}" );
    ( "top-level value shadow",
      catch_all
        "let throw = identity\ntry {read()} catch {| caught => throw(caught)}"
    );
    ( "top-level primitive shadow",
      catch_all
        "external throw: exn => int = \"customThrow\"\n\
         try {read()} catch {| caught => throw(caught)}" );
    ( "parameter shadow",
      catch_all
        "let run = throw => try {read()} catch {| caught => throw(caught)}" );
    ( "optional parameter default",
      useless
        "let run = (~throw=try {read()} catch {| caught => throw(caught)}) => \
         throw" );
    ( "nested pattern shadow",
      catch_all
        "let run = (throw, _) => try {read()} catch {| caught => throw(caught)}"
    );
    ( "catch pattern shadows throw",
      catch_all "try {read()} catch {| throw => throw(throw)}" );
    ( "switch arm shadows throw",
      catch_all
        "switch value {| Some(throw) => try {read()} catch {| caught => \
         throw(caught)} | None => 0}" );
    ( "local let shadows throw",
      catch_all
        "let run = () => {let throw = identity; try {read()} catch {| caught \
         => throw(caught)}}" );
    ( "nonrecursive binding initializer scope",
      useless "let throw = try {read()} catch {| caught => throw(caught)}" );
    ( "recursive binding initializer scope",
      catch_all
        "let rec throw = caught => try {read()} catch {| caught => \
         throw(caught)}" );
    ( "nested recursive binding",
      catch_all
        "let run = () => {let rec throw = caught => try {read()} catch {| \
         caught => throw(caught)}; throw}" );
    ( "local scope does not leak",
      useless
        "let run = throw => throw\n\
         try {read()} catch {| caught => throw(caught)}" );
    ( "module shadow",
      catch_all
        "module Pervasives = Other\n\
         try {read()} catch {| caught => Pervasives.throw(caught)}" );
    ( "recursive module shadow",
      catch_all
        "module rec Pervasives: {} = {let run = try {read()} catch {| caught \
         => Pervasives.throw(caught)}}" );
    ( "local module shadow",
      catch_all
        "let run = () => {module Pervasives = Other; try {read()} catch {| \
         caught => Pervasives.throw(caught)}}" );
    ( "module initializer scope",
      useless
        "module Pervasives = {let run = try {read()} catch {| caught => \
         Pervasives.throw(caught)}}" );
    ( "functor module shadow",
      catch_all
        "module F = (Pervasives: {}) => {let run = try {read()} catch {| \
         caught => Pervasives.throw(caught)}}" );
    ( "opaque open",
      catch_all "open Other\ntry {read()} catch {| caught => throw(caught)}" );
    ( "opaque local open",
      catch_all
        "let run = {open Other; try {read()} catch {| caught => throw(caught)}}"
    );
    ( "opaque include",
      catch_all "include Other\ntry {read()} catch {| caught => throw(caught)}"
    );
    ( "unrelated module does not shadow",
      useless
        "module Other = {}\ntry {read()} catch {| caught => throw(caught)}" );
    ( "unrelated callee",
      catch_all "try {read()} catch {| caught => Other.throw(caught)}" );
    ( "nonidentifier callee",
      catch_all "try {read()} catch {| caught => (makeThrow())(caught)}" );
    ( "for-loop binding shadow",
      catch_all
        "for throw in 0 to 1 {try {read()} catch {| caught => throw(caught)}}"
    );
    ( "for-loop body",
      useless
        "for index in 0 to 1 {try {read()} catch {| caught => throw(caught)}}"
    );
    ( "nested handlers",
      check
        [ "no-useless-catch"; "no-catch-all-exception" ]
        "try {try {read()} catch {| _ => 0}} catch {| caught => throw(caught)}"
    );
    ( "multiple debugger expressions",
      check
        [ "no-debugger"; "no-debugger" ]
        "let f = () => {%debugger; %debugger}" );
    ( "debugger exact range",
      exact_range "no-debugger" "// before\n%debugger" 10 19 );
    ( "catch exact range",
      exact_range "no-catch-all-exception" "try {read()} catch {| _ => 0}" 22 23
    );
    ( "try exact range",
      exact_range "no-useless-catch" "try {read()} catch {| e => throw(e)}" 0 36
    );
  ]

let () =
  let failures =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
      checks
  in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
