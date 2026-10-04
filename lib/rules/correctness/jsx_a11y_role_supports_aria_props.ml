let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/role-supports-aria-props";
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
      let unsupported =
        List.filter_map
          (fun (property : M.property) ->
            if property.optional || not (M.present property.name element) then
              None
            else
              Option.bind (M.aria_name property.name) (fun name ->
                  if
                    List.mem name role.prohibited
                    || not (List.mem name role.supported)
                  then Some name
                  else None))
          element.M.props
      in
      issue "role-supports-aria-props" (unsupported <> [])
        ("This role does not support " ^ String.concat ", " unsupported ^ "."))
    role
