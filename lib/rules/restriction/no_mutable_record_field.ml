let metadata =
  Rule_metadata.
    {
      id = "no-mutable-record-field";
      category = Restriction;
      enabled_by_default = false;
    }

let inspect emit (field : Parsetree.label_declaration) =
  if field.pld_mutable = Asttypes.Mutable then
    emit "no-mutable-record-field" "Prefer an immutable record field."
      field.pld_loc
