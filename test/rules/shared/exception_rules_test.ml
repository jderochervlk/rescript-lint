open Rescript_linter
open Exception_rules_test_support

let clean = check []

let checks =
  [
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
    ( "one handled arm",
      clean "try {read()} catch {| Not_found => 0 | caught => throw(caught)}" );
    ( "guarded rethrow",
      clean "try {read()} catch {| caught if log(caught) => throw(caught)}" );
    ("guarded swallow", clean "try {read()} catch {| _ if enabled => 0}");
    ( "constructor payload is not the original exception",
      clean "try {read()} catch {| Failure(caught) => throw(caught)}" );
    ( "constructor reconstruction conservative",
      clean "try {read()} catch {| Not_found => throw(Not_found)}" );
    ("ordinary switch", clean "switch value {| _ => 0}");
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
    ( "switch specific exception",
      clean "switch read() {| exception Not_found => 0 | value => value}" );
    ( "switch exception guard",
      clean
        "switch read() {| exception caught if enabled => 0 | value => value}" );
    ( "nested handlers",
      check
        [ "no-useless-catch"; "no-catch-all-exception" ]
        "try {try {read()} catch {| _ => 0}} catch {| caught => throw(caught)}"
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
