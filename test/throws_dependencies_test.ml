open Rescript_linter

let project_modules = [ "Api"; "Other"; "Third"; "Unused" ]

let check ?(kind = Source.Implementation) expected text =
  let source = Source.{ filename = "dependencies.res"; text; kind } in
  match Parser.parse source with
  | Error error -> Error (Lint_error.render error)
  | Ok tree ->
      let actual = Throws_dependencies.modules ~project_modules tree in
      if actual = expected then Ok ()
      else
        Error
          ("expected " ^ String.concat "," expected ^ "; got "
         ^ String.concat "," actual)

let implementation_cases =
  [
    ( "nested pattern traversal",
      [ "Api"; "Other" ],
      "let run = value => switch value {| Some((first, second)) | \
       Some((second, first)) => Api.read(first, second) | None => \
       Other.read()}" );
    ( "array pattern traversal",
      [ "Api" ],
      "let run = ([first]) => Api.read(first)" );
    ( "variant payload pattern traversal",
      [ "Api" ],
      "let run = (#Value(value)) => Api.read(value)" );
    ( "exception pattern traversal",
      [ "Api" ],
      "let run = () => switch read() {| exception Api.E => 0 | value => value}"
    );
    ( "local module type retains nested shadows",
      [],
      "module type S = {module Api: {}}; module Local: S = {module Api = {}}; \
       open Local; Api.read()" );
    ( "qualified local module type retains nested shadows",
      [],
      "module Types = {module type S = {module Api: {}}}; module Local: \
       Types.S = {module Api = {}}; open Local; Api.read()" );
    ( "module type and module namespaces differ",
      [ "Api" ],
      "module type Api = {}; Api.read()" );
    ( "local functor type parameter exports",
      [],
      "module type S = {module Api: {}}; module Build = (Input: S) => {open \
       Input; let value = Api.read()}" );
    ("record construction qualifier", [ "Api" ], "let value = {Api.field: 1}");
    ( "record pattern qualifier",
      [ "Api" ],
      "let read = ({Api.field: value}) => value" );
    ( "record assignment qualifier",
      [ "Api" ],
      "let write = value => value.Api.field = 1" );
    ("type extension path", [ "Api" ], "type Api.t += Added");
    ("qualified call", [ "Api" ], "let value = Api.read()");
    ("qualified value", [ "Api" ], "let read = Api.read");
    ( "sorted unique roots",
      [ "Api"; "Other" ],
      "Other.read(); Api.read(); Other.read()" );
    ("unrelated names", [], "let api = 1; Console.log(api)");
    ("unqualified constructor", [], "let value = Api");
    ("local module", [], "module Api = {let read = () => 1}; Api.read()");
    ("binding RHS precedes shadow", [ "Api" ], "module Api = Api; Api.read()");
    ("local alias", [ "Api" ], "module Local = Api; Local.read()");
    ( "alias retains nested shadows",
      [],
      "module Local = {module Api = {}}; module Alias = Local; open Alias; \
       Api.read()" );
    ( "qualified local alias",
      [],
      "module Local = {module Nested = {module Api = {}}}; module Alias = \
       Local.Nested; open Alias; Api.read()" );
    ("project open", [ "Api" ], "open Api; let value = read()");
    ( "local open",
      [],
      "module Local = {module Api = {}}; open Local; Api.read()" );
    ( "open does not export inherited modules",
      [ "Api" ],
      "module Local = {module Api = {}}; module Facade = {open Local}; open \
       Facade; Api.read()" );
    ("project include", [ "Api" ], "include Api");
    ("local include shadows", [], "include {module Api = {}}; Api.read()");
    ( "exported alias",
      [ "Api" ],
      "module Facade = {module Exported = Api}; Facade.Exported.read()" );
    ("function body counts", [ "Api" ], "let run = () => Api.read()");
    ( "function module parameter",
      [],
      "module type S = {let read: unit => int}; let run = (module(Api: S)) => \
       Api.read()" );
    ( "match module binding",
      [],
      "module type S = {let read: unit => int}; let run = value => switch \
       value {| module(Api: S) => Api.read()}" );
    ( "local module expression",
      [ "Other" ],
      "let run = () => {module Api = Other; Api.read()}" );
    ( "local open expression",
      [],
      "module Local = {module Api = {}}; let run = () => {open Local; \
       Api.read()}" );
    ( "functor parameter",
      [ "Other" ],
      "module Build = (Api: Other.S) => {let value = Api.read()}" );
    ("functor argument", [ "Api"; "Other" ], "module Result = Api.Build(Other)");
    ( "recursive module shadows",
      [],
      "module type S = {let read: unit => int}; module rec Api: S = {let read \
       = () => Api.read()}; Api.read()" );
    ("type reference", [ "Api" ], "type value = Api.t");
    ( "exception constructor and pattern",
      [ "Api"; "Other" ],
      "let run = () => try raise(Api.E) catch {| Other.E => 0}" );
    ("exception alias", [ "Api" ], "exception E = Api.E");
    ("record qualified field", [ "Api" ], "let read = value => value.Api.field");
    ("throws payload", [ "Api" ], "@throws(Api.E) let read = () => 0");
    ( "raises array payload",
      [ "Api"; "Other" ],
      "@raises([Other.E, Api.E]) let read = () => 0" );
    ("standalone throws payload", [ "Api" ], "@@throws(Api.E)");
    ( "nonthrows attributes ignored",
      [],
      "@example(Api.read()) let read = () => 0; @@example(Other.read())" );
    ( "shadowed throws payload",
      [],
      "module Api = {}; @throws(Api.E) let read = () => 0" );
    ( "nested modules do not leak shadows",
      [ "Api" ],
      "module Local = {module Api = {}}; Api.read()" );
    ("module constraint", [ "Api"; "Other" ], "module Local: Other.S = Api");
    ( "explicit signature shadow",
      [],
      "module Local: {module Api: {}} = {module Api = {}}; open Local; \
       Api.read()" );
    ("package type", [ "Api" ], "let read = (value: module(Api.S)) => value");
    ( "defaults and guards",
      [ "Api"; "Other" ],
      "let read = (~value=Api.read()) => switch value {| x if Other.valid(x) \
       => x | x => x}" );
    ( "nested let RHS",
      [ "Api" ],
      "let run = () => {let value = Api.read(); value}" );
  ]

let interface_cases =
  [
    ( "interface local module type exports",
      [],
      "module type S = {module Api: {}}\n\
       module Local: S\n\
       open Local\n\
       let read: Api.t => int" );
    ( "interface abstract module type",
      [ "Api" ],
      "module type S\nlet read: Api.t => int" );
    ("interface contract", [ "Api" ], "@throws(Api.E) let read: unit => int");
    ("interface qualified type", [ "Api" ], "let read: Api.t => int");
    ("interface alias", [ "Api" ], "module Local = Api");
    ( "interface local module shadows",
      [],
      "module Api: {let read: unit => int}; let read: Api.t => int" );
    ("interface open", [ "Api" ], "open Api; let read: t => int");
    ( "interface local open",
      [],
      "module Local: {module Api: {}}; open Local; let read: Api.t => int" );
    ("interface include", [ "Api" ], "include module type of Api");
    ( "interface local include",
      [],
      "include {module Api: {}}; let read: Api.t => int" );
    ( "interface nested alias",
      [ "Api" ],
      "module Local: {module Exported = Api}" );
    ( "interface recursive shadow",
      [],
      "module rec Api: {let read: Api.t => int}" );
    ( "interface functor shadow",
      [ "Other" ],
      "module Build: (Api: Other.S) => {let read: Api.t => int}" );
    ( "interface ignored attribute",
      [],
      "@@example(Api.read()); @example(Other.read()) let read: unit => int" );
    ("interface standalone contract", [ "Api" ], "@@raises(Api.E)");
  ]

let () =
  let run kind cases =
    List.filter_map
      (fun (name, expected, text) ->
        match check ~kind expected text with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
      cases
  in
  let failures =
    run Source.Implementation implementation_cases
    @ run Interface interface_cases
  in
  match failures with
  | [] ->
      Printf.printf "throws dependencies: %d checks passed\n"
        (List.length implementation_cases + List.length interface_cases)
  | _ ->
      List.iter prerr_endline failures;
      exit 1
