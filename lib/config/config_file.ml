let decode_string = function
  | `String value -> Ok value
  | _ -> Error "Expected a string."

let decode_string_list = function
  | `List values ->
      List.fold_left
        (fun result value ->
          Result.bind result (fun values ->
              Result.map (fun value -> value :: values) (decode_string value)))
        (Ok []) values
      |> Result.map List.rev
  | _ -> Error "Expected an array of strings."

let decode_nonnegative_int = function
  | `Int value when value >= 0 -> Ok value
  | _ -> Error "Expected a non-negative integer."

let resolve_path ~base value =
  if Filename.is_relative value then Filename.concat base value else value

let decode_paths ~base value =
  Result.bind (decode_string_list value) (fun values ->
      if List.exists (fun value -> String.trim value = "") values then
        Error "Paths must not be empty."
      else Ok (List.map (resolve_path ~base) values))

let decode_nonempty_string ~key value =
  Result.bind (decode_string value) (fun value ->
      if String.trim value = "" then Error (key ^ " must not be empty.")
      else Ok value)

let decode_nullable_adapter ~key ~name adapter = function
  | `String value when value = name -> Ok (Some adapter)
  | `Null -> Ok None
  | _ -> Error ("Unsupported " ^ key ^ ".")

let decode_deep_equality_threshold = function
  | `Int value when value >= 2 -> Ok value
  | _ -> Error "deepEqualityThreshold must be an integer of at least 2."

let map_decoder decode update value = Result.map update (decode value)

let decode_rules config = function
  | `Assoc entries ->
      let ids = List.map fst entries in
      if List.length ids <> List.length (List.sort_uniq String.compare ids) then
        Error "Duplicate rule settings are not allowed."
      else
        List.fold_left
          (fun result (id, value) ->
            Result.bind result (fun config ->
                match value with
                | `Bool enabled -> Rule_config.set config ~id ~enabled
                | _ -> Error ("Rule " ^ id ^ " requires true or false.")))
          (Ok config) entries
  | _ -> Error "rules must be an object of rule IDs and booleans."

let adapter_decoders (options : Project_options.t) =
  [
    ( "jsxRuntime",
      map_decoder
        (decode_nullable_adapter ~key:"jsxRuntime" ~name:"react-dom"
           Project_options.React_dom) (fun jsx_runtime ->
          { options with jsx_runtime }) );
    ( "testFramework",
      map_decoder
        (decode_nullable_adapter ~key:"testFramework" ~name:"rescript-vitest-3"
           Project_options.Rescript_vitest_3) (fun test_framework ->
          { options with test_framework }) );
    ( "throwsRuntime",
      map_decoder
        (decode_nullable_adapter ~key:"throwsRuntime" ~name:"rescript-12.3.1"
           Project_options.Rescript_12_3_1) (fun throws_runtime ->
          { options with throws_runtime }) );
  ]

let list_decoders ~base (options : Project_options.t) =
  [
    ( "restrictedModules",
      map_decoder decode_string_list (fun restricted_modules ->
          { options with restricted_modules }) );
    ( "entryModules",
      map_decoder decode_string_list (fun entry_modules ->
          { options with entry_modules }) );
    ( "exclude",
      map_decoder decode_string_list (fun excluded_paths ->
          { options with excluded_paths }) );
    ( "throwsDependencies",
      map_decoder (decode_paths ~base) (fun throws_dependencies ->
          { options with throws_dependencies }) );
    ( "forbiddenSourceRoots",
      map_decoder (decode_paths ~base) (fun forbidden_source_roots ->
          { options with forbidden_source_roots }) );
    ( "sourceRootDependencies",
      map_decoder (decode_paths ~base) (fun source_root_dependencies ->
          { options with source_root_dependencies }) );
  ]

let limit_decoders (options : Project_options.t) =
  let limits = options.limits in
  [
    ( "maxLines",
      map_decoder decode_nonnegative_int (fun max_lines ->
          { options with max_lines }) );
    ( "maxSwitchCases",
      map_decoder decode_nonnegative_int (fun max_switch_cases ->
          { options with max_switch_cases }) );
    ( "maxNesting",
      map_decoder decode_nonnegative_int (fun max_nesting ->
          { options with limits = { limits with max_nesting } }) );
    ( "maxParams",
      map_decoder decode_nonnegative_int (fun max_params ->
          { options with limits = { limits with max_params } }) );
    ( "maxLinesPerFunction",
      map_decoder decode_nonnegative_int (fun max_lines_per_function ->
          { options with limits = { limits with max_lines_per_function } }) );
    ( "maxNestedDescribe",
      map_decoder decode_nonnegative_int (fun max_nested_describe ->
          { options with max_nested_describe }) );
    ( "deepEqualityThreshold",
      map_decoder decode_deep_equality_threshold (fun deep_equality_threshold ->
          { options with deep_equality_threshold }) );
  ]

let string_decoders ~base (options : Project_options.t) =
  [
    ( "root",
      map_decoder (decode_nonempty_string ~key:"root") (fun value ->
          { options with root = Some (resolve_path ~base value) }) );
    ( "reanalyzeReport",
      map_decoder (decode_nonempty_string ~key:"reanalyzeReport") (fun value ->
          { options with reanalyze_report = Some (resolve_path ~base value) })
    );
    ( "license",
      map_decoder (decode_nonempty_string ~key:"license") (fun license ->
          { options with license }) );
  ]

let policy_decoders (options : Project_options.t) =
  [
    ( "restrictions",
      map_decoder Restriction_policy.decode (fun restrictions ->
          { options with restrictions }) );
    ( "warningComments",
      map_decoder Warning_config.decode (fun warning_comments ->
          { options with warning_comments }) );
  ]

let decode_option ~base options key value =
  let decoders =
    adapter_decoders options
    @ list_decoders ~base options
    @ limit_decoders options
    @ string_decoders ~base options
    @ policy_decoders options
  in
  match List.assoc_opt key decoders with
  | Some decode -> decode value
  | None -> Error ("Unknown configuration property: " ^ key)

let decode_entry ~base config (key, value) =
  if key = "$schema" then Result.map (fun _ -> config) (decode_string value)
  else if key = "rules" then decode_rules config value
  else if key = "overrides" then Rule_config.with_overrides ~base config value
  else
    Result.map
      (fun options -> Rule_config.with_options options config)
      (decode_option ~base (Rule_config.options config) key value)

let decode ~base config = function
  | `Assoc entries ->
      let names = List.map fst entries in
      if List.length names <> List.length (List.sort_uniq String.compare names)
      then Error "Duplicate configuration properties are not allowed."
      else
        List.fold_left
          (fun result entry ->
            Result.bind result (fun config -> decode_entry ~base config entry))
          (Ok config) entries
  | _ -> Error "Configuration must be a JSON object."

let record_origins ~origin config = function
  | `Assoc entries ->
      List.fold_left
        (fun config (key, value) ->
          let keys =
            match (key, value) with
            | "rules", `Assoc rules ->
                List.map (fun (id, _) -> "rules." ^ id) rules
            | _ -> [ key ]
          in
          List.fold_left
            (fun config key -> Rule_config.with_origin ~key ~origin config)
            config keys)
        config entries
  | _ -> config

let load config filename =
  try
    let json = Yojson.Basic.from_file filename in
    decode ~base:(Filename.dirname filename) config json
    |> Result.map (fun config -> record_origins ~origin:filename config json)
  with
  | Sys_error detail -> Error ("Cannot read configuration: " ^ detail)
  | Yojson.Json_error detail -> Error ("Invalid configuration JSON: " ^ detail)
