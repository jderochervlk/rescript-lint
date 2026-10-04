module Names = Set.Make (String)

type rule = Rule_metadata.t = {
  id : string;
  category : Rule_metadata.category;
  enabled_by_default : bool;
}

type t = {
  base_rules : Names.t;
  enabled_rules : Names.t;
  options : Project_options.t;
  overrides : Rule_overrides.t list;
  origins : (string * string) list;
}

let rules = Rule_catalog.rules

let default_ids =
  List.filter_map
    (fun (rule : rule) ->
      if rule.enabled_by_default then Some rule.id else None)
    rules

let default =
  {
    base_rules = Names.of_list default_ids;
    enabled_rules = Names.of_list default_ids;
    options = Project_options.default;
    overrides = [];
    origins = [];
  }

let enabled config id = Names.mem id config.enabled_rules
let options config = config.options
let with_options options config = { config with options }
let enabled_ids config = Names.elements config.enabled_rules

let with_origin ~key ~origin config =
  {
    config with
    origins = (key, origin) :: List.remove_assoc key config.origins;
  }

let origin config key =
  Option.value ~default:"default" (List.assoc_opt key config.origins)

let rule_origin ~filename config id =
  match Rule_overrides.matching_index ~filename ~id config.overrides with
  | None -> origin config ("rules." ^ id)
  | Some index ->
      Printf.sprintf "%s overrides[%d]" (origin config "overrides") index

let set config ~id ~enabled =
  if List.exists (fun rule -> String.equal rule.id id) rules then
    let enabled_rules =
      if enabled then Names.add id config.base_rules
      else Names.remove id config.base_rules
    in
    Ok { config with base_rules = enabled_rules; enabled_rules }
  else Error ("Unknown rule: " ^ id)

let for_file ~filename config =
  let enabled_rules =
    List.fold_left
      (fun rules (id, enabled) ->
        if enabled then Names.add id rules else Names.remove id rules)
      config.base_rules
      (Rule_overrides.settings_for_file ~filename config.overrides)
  in
  { config with enabled_rules }

let with_overrides ~base config json =
  try
    Rule_overrides.decode ~cwd:(Sys.getcwd ()) ~base
      ~known_ids:(List.map (fun rule -> rule.id) rules)
      json
    |> Result.map (fun overrides ->
        { config with overrides; enabled_rules = config.base_rules })
  with Sys_error detail -> Error ("Cannot resolve override paths: " ^ detail)

let listing =
  rules
  |> List.map (fun rule ->
      rule.id ^ if rule.enabled_by_default then " (enabled)" else " (disabled)")
  |> String.concat "\n"
