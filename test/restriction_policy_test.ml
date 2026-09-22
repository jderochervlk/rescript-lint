open Rescript_linter

let entry ?message ?url kind path =
  `Assoc
    ([ ("kind", `String kind); ("path", `String path) ]
    @ Option.fold ~none:[]
        ~some:(fun value -> [ ("message", `String value) ])
        message
    @ Option.fold ~none:[] ~some:(fun value -> [ ("url", `String value) ]) url)

let policies =
  [
    entry ~message:"Use the public collection API." "module" "Array";
    entry ~message:"Use a list." ~url:"https://example.com/policy" "type"
      "Array.t";
    entry ~message:"Use a fold." "value" "Array.map";
  ]

let config entries =
  Config_file.decode ~base:"." Rule_config.default
    (`Assoc
       [
         ("rules", `Assoc [ ("no-restricted-modules", `Bool true) ]);
         ("restrictions", `List entries);
       ])

let lint ?(kind = Source.Implementation) entries text =
  let source =
    Source.
      {
        filename = (if kind = Interface then "Policy.resi" else "Policy.res");
        text;
        kind;
      }
  in
  Result.bind (config entries) (fun config ->
      Linter.lint_source_with_rules config source
      |> Result.map_error Lint_error.render
      |> Result.map
           (List.filter (fun (finding : Diagnostic.t) ->
                finding.rule = "no-restricted-modules")))

let check ?kind entries count text =
  Result.bind (lint ?kind entries text) (fun findings ->
      if List.length findings = count then Ok ()
      else
        Error
          (Printf.sprintf "Expected %d, got %d in %s" count
             (List.length findings) text))

let exact = [ entry "type" "Array.t" ]

let checks =
  [
    ("value policy", check policies 1 "let value = Array.map(items, fn)");
    ("type declaration", check policies 1 "type values = Array.t<int>");
    ("type nested", check exact 2 "type values = Array.t<Array.t<int>>");
    ("type binding", check exact 1 "let value: Array.t<int> = []");
    ("type parameter", check exact 1 "let f = (value: Array.t<int>) => value");
    ( "type match pattern",
      check exact 1 "switch value {| (x: Array.t<int>) => x}" );
    ("type result", check exact 1 "let f = (): Array.t<int> => []");
    ("type record field", check exact 1 "type values = {field: Array.t<int>}");
    ("type variant payload", check exact 1 "type values = Values(Array.t<int>)");
    ("type exception payload", check exact 1 "exception Values(Array.t<int>)");
    ( "type external",
      check exact 1 "@val external values: Array.t<int> = \"values\"" );
    ( "type module alias",
      check exact 1 "module A = Array\ntype values = A.t<int>" );
    ("type open", check exact 1 "open Array\ntype values = t<int>");
    ("type include", check exact 1 "include Array\ntype values = t<int>");
    ( "type local shadow",
      check exact 0
        "module Array = {type t<'a> = list<'a>}\ntype values = Array.t<int>" );
    ( "type local name shadow",
      check exact 0 "open Array\ntype t<'a> = list<'a>\ntype values = t<int>" );
    ("unknown type", check exact 0 "type values = Other.t<int>");
    ("unknown open", check exact 0 "open Other\ntype values = Array.t<int>");
    ( "value namespace distinct",
      check [ entry "value" "Array.t" ] 0 "type values = Array.t<int>" );
    ( "type namespace distinct",
      check [ entry "type" "Array.map" ] 0 "let f = Array.map" );
    ( "module prefix boundary",
      check [ entry "module" "Arr" ] 0 "let f = Array.map" );
    ("module reference", check policies 1 "module A = Array");
    ("alias and value", check policies 2 "module A = Array\nlet f = A.map");
    ("value alias use", check policies 2 "let map = Array.map\nlet f = map");
    ("signature value", check ~kind:Interface exact 1 "let value: Array.t<int>");
    ( "signature open",
      check ~kind:Interface exact 1 "open Array\nlet value: t<int>" );
    ( "signature nested",
      check ~kind:Interface exact 1 "module Nested: {let value: Array.t<int>}"
    );
    ( "signature shadow",
      check ~kind:Interface exact 0
        "module Array: {type t<'a>}\nlet value: Array.t<int>" );
    ( "signature include",
      check ~kind:Interface exact 1 "include {let value: Array.t<int>}" );
    ( "module constraint",
      check exact 1
        "module Values: {let value: Array.t<int>} = {let value = []}" );
    ( "module type",
      check exact 1 "module type Values = {let value: Array.t<int>}" );
    ( "module type alias remains unknown",
      check exact 0 "module type Alias = Unknown" );
    ( "module parameter",
      check exact 1
        "module Make = (Arg: {let value: Array.t<int>}) => {let value = \
         Arg.value}" );
    ( "module type parameter",
      check ~kind:Interface exact 1
        "module Make: (Arg: {let value: Array.t<int>}) => {let value: int}" );
    ( "type attribute ignored",
      check exact 0 "@example((unknown: Array.t<int>)) let value = 1" );
    ( "guidance and symbol",
      Result.bind (lint policies "let value: Array.t<int> = []") (function
        | [ finding ]
          when finding.help
               = Some
                   Diagnostic.
                     {
                       message = "Use a list.";
                       url = Some "https://example.com/policy";
                     }
               && finding.symbol
                  = Some Diagnostic.{ kind = Type; path = "Array.t" } ->
            Ok ()
        | _ -> Error "Missing exact-policy metadata") );
    ( "legacy supports types",
      Result.bind
        (Config_file.decode ~base:"." Rule_config.default
           (`Assoc
              [
                ("rules", `Assoc [ ("no-restricted-modules", `Bool true) ]);
                ("restrictedModules", `List [ `String "Array" ]);
              ]))
        (fun config ->
          match
            Linter.lint_source_with_rules config
              Source.
                {
                  filename = "a.resi";
                  kind = Interface;
                  text = "let value: Array.t<int>";
                }
          with
          | Ok [ finding ] when finding.rule = "no-restricted-modules" -> Ok ()
          | _ -> Error "Legacy type use missed") );
  ]

let matching entries kind path message =
  Result.bind
    (Restriction_policy.decode (`List entries))
    (fun policy ->
      let found = Restriction_policy.matching ~legacy:[] policy ~kind ~path in
      let actual =
        Option.bind found Restriction_policy.guidance
        |> Option.map (fun (help : Diagnostic.help) -> help.message)
      in
      if actual = message then Ok () else Error "Wrong overlap priority")

let precedence =
  [
    ( "longest prefix",
      matching
        [
          entry ~message:"broad" "module" "Api";
          entry ~message:"nested" "module" "Api.Nested";
        ]
        Value "Api.Nested.call" (Some "nested") );
    ( "exact beats prefix",
      matching
        [
          entry ~message:"broad" "module" "Api";
          entry ~message:"exact" "value" "Api.call";
        ]
        Value "Api.call" (Some "exact") );
    ( "first equal wins",
      matching
        [
          entry ~message:"first" "type" "Api.t";
          entry ~message:"second" "type" "Api.t";
        ]
        Type "Api.t" (Some "first") );
    ("unmatched", matching policies Value "Other.call" None);
    ( "exact requires full path",
      matching
        [ entry ~message:"exact" "value" "Api.call" ]
        Value "Api.call.other" None );
    ( "valid identifier characters",
      matching
        [ entry ~message:"valid" "value" "_value'" ]
        Value "_value'" (Some "valid") );
    ("no guidance", matching [ entry "module" "Api" ] Module "Api" None);
  ]

let invalid_values =
  [
    `Null;
    `List [ `Null ];
    `List [ `Assoc [] ];
    `List [ entry "other" "Array" ];
    `List [ entry "value" "" ];
    `List [ entry "value" "Array..map" ];
    `List [ entry "value" "Array.*" ];
    `List [ entry "value" "123" ];
    `List [ entry "value" "Api.1map" ];
    `List [ entry "type" "'value" ];
    `List [ entry ~message:" " "value" "Array.map" ];
    `List [ entry ~url:"https://example.com" "module" "Array" ];
    `List [ entry ~message:"help" ~url:"javascript:alert(1)" "module" "Array" ];
    `List
      [
        `Assoc
          [
            ("kind", `String "module");
            ("kind", `String "value");
            ("path", `String "Array");
          ];
      ];
    `List
      [
        `Assoc
          [
            ("kind", `String "module");
            ("path", `String "Array");
            ("typo", `Bool true);
          ];
      ];
  ]

let () =
  let invalid =
    List.mapi
      (fun index value ->
        ( "invalid " ^ string_of_int index,
          if Result.is_error (Restriction_policy.decode value) then Ok ()
          else Error "Invalid restriction accepted" ))
      invalid_values
  in
  let failures =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
      (checks @ precedence @ invalid)
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
