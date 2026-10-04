open Rescript_linter
open Dependency_package_test_support

let decode_good name json predicate =
  ( name,
    match Package_config.decode json with
    | Ok config when predicate config -> Ok ()
    | Ok _ -> Error "Decoded package configuration mismatch"
    | Error detail -> Error detail )

let decode_bad name json =
  ( name,
    match Package_config.decode json with
    | Error _ -> Ok ()
    | Ok _ -> Error "Invalid configuration accepted" )

let config_checks =
  let base fields =
    `Assoc (("name", `String "pkg") :: ("sources", `String "src") :: fields)
  in
  [
    decode_good "legacy dependency field"
      (base [ ("bs-dependencies", `List [ `String "dep" ]) ])
      (fun c -> c.dependencies = [ "dep" ]);
    decode_good "array source descriptions"
      (manifest
         ~sources:
           (`List
              [
                `String "src";
                `Assoc [ ("dir", `String "lib"); ("subdirs", `Bool true) ];
              ])
         "pkg")
      (fun c -> List.length c.directories = 2);
    decode_good "development sources excluded"
      (manifest
         ~sources:
           (`Assoc
              [
                ("dir", `String "test");
                ("type", `String "dev");
                ("subdirs", `Bool true);
              ])
         "pkg")
      (fun c -> c.directories = []);
    decode_good "uppercase custom namespace"
      (base [ ("namespace", `String "XML") ])
      (fun c -> c.namespace = Some "XML");
    decode_bad "config object required" (`List []);
    decode_bad "duplicate config property" (base [ ("name", `String "other") ]);
    decode_bad "package name required" (`Assoc [ ("sources", `String "src") ]);
    decode_bad "nonempty name required" (manifest "");
    decode_bad "sources required" (`Assoc [ ("name", `String "pkg") ]);
    decode_bad "dependency array required"
      (base [ ("dependencies", `String "dep") ]);
    decode_bad "dependency name required"
      (base [ ("dependencies", `List [ `Int 1 ]) ]);
    decode_bad "dependency key conflict"
      (base [ ("dependencies", `List []); ("bs-dependencies", `List []) ]);
    decode_bad "namespace type" (base [ ("namespace", `Int 1) ]);
    decode_bad "namespace entry unsupported"
      (base [ ("namespace-entry", `String "Index") ]);
    decode_bad "invalid normalized namespace"
      (base [ ("namespace", `String "123") ]);
    decode_bad "nonempty compiler flags unsupported"
      (base [ ("bsc-flags", `List [ `String "-open" ]) ]);
    decode_bad "invalid source kind" (manifest ~sources:(`Int 1) "pkg");
    decode_bad "empty source path" (manifest ~sources:(`String "") "pkg");
    decode_bad "nested source tree unsupported"
      (manifest
         ~sources:(`Assoc [ ("dir", `String "src"); ("subdirs", `List []) ])
         "pkg");
    decode_bad "unknown source field"
      (manifest
         ~sources:(`Assoc [ ("dir", `String "src"); ("files", `List []) ])
         "pkg");
    decode_bad "duplicate source field"
      (manifest
         ~sources:(`Assoc [ ("dir", `String "src"); ("dir", `String "other") ])
         "pkg");
  ]

let () =
  let failures =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
      config_checks
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
