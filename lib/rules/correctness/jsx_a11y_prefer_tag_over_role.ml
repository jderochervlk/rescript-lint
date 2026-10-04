let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/prefer-tag-over-role";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let element = context.element in
  Option.fold ~none:[]
    ~some:(fun (role : M.role) ->
      let implicit = M.implicit_role element in
      let redundant =
        implicit = Some role.M.role_name
        || (implicit = Some "presentation" && role.role_name = "none")
      in
      issue "prefer-tag-over-role"
        ((not redundant) && Option.is_some (M.native_tag role.role_name))
        ("Prefer the native element for the " ^ role.role_name ^ " role."))
    (M.explicit_role element)
