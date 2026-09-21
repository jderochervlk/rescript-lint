module Names = Set.Make (String)

type rule = { id : string; enabled_by_default : bool }
type t = { enabled_rules : Names.t; options : Project_options.t }

let default_ids =
  [
    "no-console";
    "no-object-magic";
    "no-unsafe";
    "react/rules-of-hooks";
    "no-unhandled-throws";
    "blank-lines";
    "no-constant-condition";
    "no-constant-binary-expression";
    "no-duplicate-condition";
    "no-identical-branches";
    "no-debugger";
    "no-useless-catch";
  ]

let optional_ids =
  [
    "no-catch-all-exception";
    "simplify-boolean-expression";
    "no-useless-concat";
    "approx-constant";
    "no-empty-function";
    "no-empty-file";
    "no-warning-comments";
    "max-nesting";
    "max-params";
    "max-lines-per-function";
  ]
  @ Semantic_rules.rule_ids @ Jsx_rules.rule_ids @ React_dom_rules.rule_ids
  @ React_semantic_rules.rule_ids @ Test_rules.rule_ids
  @ [
      "no-restricted-modules";
      "no-unused-export";
      "no-deprecated-api";
      "require-interface";
      "require-license-header";
    ]

let rules =
  List.map (fun id -> { id; enabled_by_default = true }) default_ids
  @ List.map (fun id -> { id; enabled_by_default = false }) optional_ids

let default =
  {
    enabled_rules = Names.of_list default_ids;
    options = Project_options.default;
  }

let enabled config id = Names.mem id config.enabled_rules
let options config = config.options
let with_options options config = { config with options }
let enabled_ids config = Names.elements config.enabled_rules

let set config ~id ~enabled =
  if List.exists (fun rule -> String.equal rule.id id) rules then
    let enabled_rules =
      if enabled then Names.add id config.enabled_rules
      else Names.remove id config.enabled_rules
    in
    Ok { config with enabled_rules }
  else Error ("Unknown rule: " ^ id)

let listing =
  rules
  |> List.map (fun rule ->
      rule.id ^ if rule.enabled_by_default then " (enabled)" else " (disabled)")
  |> String.concat "\n"
