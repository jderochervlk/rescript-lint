let metadata =
  Rule_metadata.
    {
      id = "react/no-unstable-nested-components";
      category = Suspicious;
      enabled_by_default = false;
    }

let inspect ~source emit ~render (binding : Parsetree.value_binding) =
  if render then
    emit
      (Jsx_model.emit ~source "react/no-unstable-nested-components"
         "Move this component definition outside the rendering component."
         binding.pvb_loc)
