let metadata =
  Rule_metadata.
    {
      id = "react/no-new-prop-value";
      category = Perf;
      enabled_by_default = false;
    }

open React_semantic_support

let inspect ~source emit element =
  List.iter
    (fun property ->
      match property.Jsx_model.value with
      | Some value
        when allocated value
             && not (List.mem property.name [ "children"; "key"; "ref" ]) ->
          emit
            (Jsx_model.emit ~source "react/no-new-prop-value"
               ("This " ^ property.name
              ^ " prop is allocated during every render.")
               property.location)
      | _ -> ())
    element.Jsx_model.props
