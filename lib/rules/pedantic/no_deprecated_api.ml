let metadata =
  Rule_metadata.
    {
      id = "no-deprecated-api";
      category = Pedantic;
      enabled_by_default = false;
    }

open Project_rule_support

let deprecated attributes =
  List.find_map
    (fun (name, payload) ->
      if name.Location.txt <> "deprecated" then None
      else
        Some
          (match payload with
          | Parsetree.PStr
              [
                {
                  pstr_desc =
                    Pstr_eval
                      ( {
                          pexp_desc = Pexp_constant (Pconst_string (message, _));
                          _;
                        },
                        _ );
                  _;
                };
              ] ->
              message
          | _ -> "Use the supported replacement API."))
    attributes

let inspect ~source emit scope identifier location =
  Option.iter
    (fun value ->
      Option.iter
        (fun message ->
          emit
            (diagnostic source "no-deprecated-api"
               ("This API is deprecated. " ^ message)
               location))
        (deprecated value.Semantic_model.attributes))
    (Semantic_model.resolve scope identifier)
