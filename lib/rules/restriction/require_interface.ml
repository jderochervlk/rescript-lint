let metadata =
  Rule_metadata.
    {
      id = "require-interface";
      category = Restriction;
      enabled_by_default = false;
    }

open Project_rule_support

let interface_findings ~source project =
  match source.Source.kind with
  | Interface -> []
  | Implementation ->
      let exists =
        List.exists
          (fun unit ->
            Project_files.canonical unit.Project_files.source.filename
            = Project_files.canonical source.filename
            && Project_files.has_interface project unit)
          project.Project_files.units
      in
      if exists then []
      else
        [
          file_diagnostic source "require-interface"
            "Add a matching .resi interface for this implementation.";
        ]
