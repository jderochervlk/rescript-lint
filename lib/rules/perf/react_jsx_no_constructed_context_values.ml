let metadata =
  Rule_metadata.
    {
      id = "react/jsx-no-constructed-context-values";
      category = Perf;
      enabled_by_default = false;
    }

open React_semantic_support

let inspect ~source emit scope element =
  if provider scope element then
    match Jsx_model.prop "value" element with
    | Value expression when allocated expression ->
        emit
          (Jsx_model.emit ~source "react/jsx-no-constructed-context-values"
             "This context value is allocated during every render; provide a \
              stable value."
             expression.pexp_loc)
    | _ -> ()
