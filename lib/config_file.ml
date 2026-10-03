let string = function
  | `String value -> Ok value
  | _ -> Error "Expected a string."

let strings = function
  | `List values ->
      List.fold_left
        (fun result value ->
          Result.bind result (fun values ->
              Result.map (fun value -> value :: values) (string value)))
        (Ok []) values
      |> Result.map List.rev
  | _ -> Error "Expected an array of strings."

let positive = function
  | `Int value when value >= 0 -> Ok value
  | _ -> Error "Expected a non-negative integer."

let path ~base value =
  if Filename.is_relative value then Filename.concat base value else value

let paths ~base value =
  Result.bind (strings value) (fun values ->
      if List.exists (fun value -> String.trim value = "") values then
        Error "Paths must not be empty."
      else Ok (List.map (path ~base) values))

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

let decode_adapter options key value =
  match (key, value) with
  | "jsxRuntime", `String "react-dom" ->
      Ok { options with Project_options.jsx_runtime = Some React_dom }
  | "jsxRuntime", `Null ->
      Ok { options with Project_options.jsx_runtime = None }
  | "testFramework", `String "rescript-vitest-3" ->
      Ok
        { options with Project_options.test_framework = Some Rescript_vitest_3 }
  | "testFramework", `Null ->
      Ok { options with Project_options.test_framework = None }
  | "throwsRuntime", `String "rescript-12.3.1" ->
      Ok { options with Project_options.throws_runtime = Some Rescript_12_3_1 }
  | "throwsRuntime", `Null ->
      Ok { options with Project_options.throws_runtime = None }
  | _ -> Error ("Unsupported " ^ key ^ ".")

let decode_list options key value =
  Result.map
    (fun values ->
      match key with
      | "restrictedModules" ->
          { options with Project_options.restricted_modules = values }
      | "entryModules" ->
          { options with Project_options.entry_modules = values }
      | _ -> { options with Project_options.excluded_paths = values })
    (strings value)

let decode_limit options key value =
  Result.map
    (fun value ->
      let limits = options.Project_options.limits in
      match key with
      | "maxLines" -> { options with max_lines = value }
      | "maxSwitchCases" -> { options with max_switch_cases = value }
      | "maxNesting" ->
          { options with limits = { limits with max_nesting = value } }
      | "maxParams" ->
          { options with limits = { limits with max_params = value } }
      | "maxLinesPerFunction" ->
          {
            options with
            limits = { limits with max_lines_per_function = value };
          }
      | _ -> { options with max_nested_describe = value })
    (positive value)

let decode_string ~base options key value =
  Result.bind (string value) (fun value ->
      if String.trim value = "" then Error (key ^ " must not be empty.")
      else
        Ok
          (match key with
          | "root" ->
              { options with Project_options.root = Some (path ~base value) }
          | "reanalyzeReport" ->
              {
                options with
                Project_options.reanalyze_report = Some (path ~base value);
              }
          | _ -> { options with Project_options.license = value }))

let decode_option ~base options key value =
  match key with
  | "restrictions" ->
      Result.map
        (fun restrictions -> { options with Project_options.restrictions })
        (Restriction_policy.decode value)
  | "warningComments" ->
      Result.map
        (fun warning_comments ->
          { options with Project_options.warning_comments })
        (Warning_config.decode value)
  | "throwsDependencies" ->
      Result.map
        (fun throws_dependencies ->
          { options with Project_options.throws_dependencies })
        (paths ~base value)
  | "jsxRuntime" | "testFramework" | "throwsRuntime" ->
      decode_adapter options key value
  | "restrictedModules" | "entryModules" | "exclude" ->
      decode_list options key value
  | "maxNesting" | "maxParams" | "maxLinesPerFunction" | "maxNestedDescribe"
  | "maxLines" | "maxSwitchCases" ->
      decode_limit options key value
  | "root" | "reanalyzeReport" | "license" ->
      decode_string ~base options key value
  | "deepEqualityThreshold" -> (
      match value with
      | `Int value when value >= 2 ->
          Ok { options with Project_options.deep_equality_threshold = value }
      | _ -> Error "deepEqualityThreshold must be an integer of at least 2.")
  | _ -> Error ("Unknown configuration property: " ^ key)

let decode_entry ~base config (key, value) =
  if key = "$schema" then Result.map (fun _ -> config) (string value)
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
