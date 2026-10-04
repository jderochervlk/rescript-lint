let metadata =
  Rule_metadata.
    {
      id = "jsx-a11y/no-interactive-element-to-noninteractive-role";
      category = Correctness;
      enabled_by_default = false;
    }

open Jsx_rule_support

let inspect (context : context) =
  let element = context.element in
  Option.fold ~none:[]
    ~some:(fun (role : M.role) ->
      issue "no-interactive-element-to-noninteractive-role"
        (M.native_interactive element = Some true && not role.interactive)
        "Keep the native interactive semantics of this element.")
    (M.explicit_role element)
