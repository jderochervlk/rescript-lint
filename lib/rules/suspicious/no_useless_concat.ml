let metadata =
  Rule_metadata.
    {
      id = "no-useless-concat";
      category = Suspicious;
      enabled_by_default = false;
    }

open Expression_rule_support

let useless_concat ~source expression =
  match binary ~source expression with
  | Some ("++", left, right) -> (
      match (string_literal left, string_literal right) with
      | Some _, Some _ | Some "", _ | _, Some "" -> true
      | _ -> false)
  | _ -> false

let inspect ~source expression =
  if useless_concat ~source expression then
    Some
      ( "no-useless-concat",
        "Avoid concatenating string literals or an empty string." )
  else None
