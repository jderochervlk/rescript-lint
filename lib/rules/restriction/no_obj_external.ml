let metadata =
  Rule_metadata.
    {
      id = "no-obj-external";
      category = Restriction;
      enabled_by_default = false;
    }

open Syntax_policy_support

let inspect_external emit (value : Parsetree.value_description) =
  if
    attribute "obj" value.pval_attributes
    || attribute "bs.obj" value.pval_attributes
  then
    emit "no-obj-external"
      "Prefer a record or object expression to an @obj external." value.pval_loc
