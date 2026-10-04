let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/no-redundant-roles";
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
      issue "no-redundant-roles" redundant
        "This role repeats the element's native semantics.")
    (M.explicit_role element)
