let metadata =
  Rule_metadata.
    {
      id = "no-object-magic";
      category = Correctness;
      enabled_by_default = true;
    }

let message = function
  | [
      (("Obj" | "Primitive_object" | "Primitive_object_extern") as root);
      "magic";
    ] ->
      Some
        ("Do not use " ^ root
       ^ ".magic. Use a typed conversion or validate the input.")
  | _ -> None

let rule = Banned_api.{ id = "no-object-magic"; message }
