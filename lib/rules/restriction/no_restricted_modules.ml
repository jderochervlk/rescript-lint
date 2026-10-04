let metadata =
  Rule_metadata.
    {
      id = "no-restricted-modules";
      category = Restriction;
      enabled_by_default = false;
    }

open Project_rule_support

let inspect_policy ~source ~(options : Project_options.t) emit kind path
    location =
  let path = String.concat "." path in
  Option.iter
    (fun entry ->
      let finding =
        diagnostic source "no-restricted-modules"
          ("This reference is restricted: " ^ path ^ ".")
          location
      in
      emit
        {
          finding with
          help = Restriction_policy.guidance entry;
          symbol = Some Diagnostic.{ kind; path };
        })
    (Restriction_policy.matching ~legacy:options.restricted_modules
       options.restrictions ~kind ~path)

let validate ~source (options : Project_options.t) =
  if
    options.restricted_modules = []
    && Restriction_policy.is_empty options.restrictions
  then
    failure source
      "no-restricted-modules requires a nonempty restrictedModules or \
       restrictions policy."
  else Ok ()
