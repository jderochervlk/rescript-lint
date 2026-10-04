let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/role-has-required-aria-props";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let element = context.element in
  let role =
    match M.explicit_role element with
    | Some role -> Some role
    | None when M.absent "role" element ->
        Option.bind (M.implicit_role element) M.find_role
    | None -> None
  in
  Option.fold ~none:[]
    ~some:(fun (role : M.role) ->
      let native = M.implicit_role element = Some role.M.role_name in
      let missing =
        if native then []
        else
          List.filter
            (fun name -> M.absent (react_aria_name name) element)
            role.required
      in
      issue "role-has-required-aria-props" (missing <> [])
        ("This role requires " ^ String.concat ", " missing ^ "."))
    role
