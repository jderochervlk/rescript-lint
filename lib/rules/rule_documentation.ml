let base_url =
  "https://github.com/jderochervlk/rescript-lint/blob/main/docs/rules/"

let url (rule : string) : string option =
  if
    List.exists
      (fun (metadata : Rule_metadata.t) -> String.equal metadata.id rule)
      Rule_catalog.rules
  then Some (base_url ^ rule ^ ".md")
  else None
