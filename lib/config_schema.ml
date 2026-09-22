let string = `Assoc [ ("type", `String "string") ]
let boolean = `Assoc [ ("type", `String "boolean") ]

let integer minimum =
  `Assoc [ ("type", `String "integer"); ("minimum", `Int minimum) ]

let array items = `Assoc [ ("type", `String "array"); ("items", items) ]

let object_ properties =
  `Assoc
    [
      ("type", `String "object");
      ("additionalProperties", `Bool false);
      ("properties", `Assoc properties);
    ]

let enum values = `Assoc [ ("enum", `List values) ]
let adapter name = enum [ `String name; `Null ]
let nonempty = `Assoc [ ("type", `String "string"); ("pattern", `String "\\S") ]

let rules =
  object_
    (List.map
       (fun (rule : Rule_config.rule) -> (rule.id, boolean))
       Rule_config.rules)

let extend fields = function
  | `Assoc properties -> `Assoc (properties @ fields)
  | value -> value

let overrides =
  let path =
    extend
      [
        ( "allOf",
          `List
            [
              `Assoc
                [
                  ( "not",
                    `Assoc [ ("pattern", `String "[\\\\*?\\[\\]{}\\u0000]") ] );
                ];
              `Assoc
                [
                  ("not", `Assoc [ ("pattern", `String "^!|(^|/)\\.\\.(/|$)") ]);
                ];
            ] );
      ]
      nonempty
  in
  let paths =
    extend [ ("minItems", `Int 1); ("uniqueItems", `Bool true) ] (array path)
  in
  array
    (extend
       [ ("required", `List [ `String "paths"; `String "rules" ]) ]
       (object_
          [
            ("paths", paths);
            ("rules", extend [ ("minProperties", `Int 1) ] rules);
          ]))

let warning_comments =
  let terms =
    array
      (`Assoc
         [
           ("type", `String "string");
           ("pattern", `String "^[A-Za-z][A-Za-z0-9_]*$");
         ])
  in
  let contexts =
    array
      (enum
         (List.map
            (fun value -> `String value)
            [ "line"; "block"; "documentation" ]))
  in
  object_
    [
      ( "terms",
        extend [ ("minItems", `Int 1); ("uniqueItems", `Bool true) ] terms );
      ("allowedContexts", extend [ ("uniqueItems", `Bool true) ] contexts);
    ]

let document =
  extend
    [
      ("$schema", `String "https://json-schema.org/draft/2020-12/schema");
      ("title", `String "ReScript Linter Configuration");
      ( "description",
        `String
          "Strict configuration. Runtime validation additionally rejects \
           duplicate object keys, case-insensitive duplicate warning terms and \
           normalized duplicate override paths." );
    ]
    (object_
       ([
          ("$schema", string);
          ("rules", rules);
          ("overrides", overrides);
          ("root", nonempty);
          ("reanalyzeReport", nonempty);
          ("license", nonempty);
          ("jsxRuntime", adapter "react-dom");
          ("testFramework", adapter "rescript-vitest-3");
          ("throwsRuntime", adapter "rescript-12.3.1");
          ("throwsDependencies", array nonempty);
          ("warningComments", warning_comments);
          ( "restrictions",
            array
              (extend
                 [
                   ("required", `List [ `String "kind"; `String "path" ]);
                   ( "dependentRequired",
                     `Assoc [ ("url", `List [ `String "message" ]) ] );
                 ]
                 (object_
                    [
                      ( "kind",
                        enum
                          [ `String "module"; `String "value"; `String "type" ]
                      );
                      ( "path",
                        `Assoc
                          [
                            ("type", `String "string");
                            ( "pattern",
                              `String "^[A-Za-z0-9_']+(\\.[A-Za-z0-9_']+)*$" );
                          ] );
                      ("message", nonempty);
                      ( "url",
                        `Assoc
                          [
                            ("type", `String "string");
                            ("pattern", `String "^https?://");
                          ] );
                    ])) );
          ("deepEqualityThreshold", integer 2);
        ]
       @ List.map
           (fun name -> (name, array string))
           [ "restrictedModules"; "entryModules"; "exclude" ]
       @ List.map
           (fun name -> (name, integer 0))
           [
             "maxNesting";
             "maxParams";
             "maxLinesPerFunction";
             "maxNestedDescribe";
             "maxLines";
             "maxSwitchCases";
           ]))
