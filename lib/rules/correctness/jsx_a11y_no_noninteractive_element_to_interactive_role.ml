let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/no-noninteractive-element-to-interactive-role";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let tag = context.tag in
  let element = context.element in
  Option.fold ~none:[]
    ~some:(fun (role : M.role) ->
      let semantic_noninteractive =
        Option.exists
          (fun name ->
            Option.exists
              (fun role -> not role.M.interactive)
              (M.find_role name))
          (M.implicit_role element)
      in
      issue "no-noninteractive-element-to-interactive-role"
        (semantic_noninteractive && role.interactive
        && not (compatible_role tag role.role_name))
        "Use a native interactive element inside this semantic element.")
    (M.explicit_role element)
