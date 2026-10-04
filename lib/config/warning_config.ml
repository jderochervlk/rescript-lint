let decode_list ~field decode = function
  | `List values ->
      List.fold_left
        (fun result value ->
          Result.bind result (fun values ->
              Result.map (fun value -> value :: values) (decode value)))
        (Ok []) values
      |> Result.map List.rev
  | _ -> Error ("warningComments." ^ field ^ " must be an array.")

let term = function
  | `String value -> Ok value
  | _ -> Error "warningComments.terms must contain strings."

let context = function
  | `String "line" -> Ok Policy_rules.Line
  | `String "block" -> Ok Policy_rules.Block
  | `String "documentation" -> Ok Policy_rules.Documentation
  | _ ->
      Error
        "warningComments.allowedContexts accepts only line, block, and \
         documentation."

let decode_field ~default name decode fields =
  match List.assoc_opt name fields with
  | None -> Ok default
  | Some value -> decode_list ~field:name decode value

let validate_fields fields =
  let names = List.map fst fields in
  if List.length names <> List.length (List.sort_uniq String.compare names) then
    Error "Duplicate warningComments properties are not allowed."
  else
    match
      List.find_opt
        (fun name -> name <> "terms" && name <> "allowedContexts")
        names
    with
    | Some name -> Error ("Unknown warningComments property: " ^ name)
    | None -> Ok ()

let decode = function
  | `Assoc fields ->
      Result.bind (validate_fields fields) (fun () ->
          Result.bind
            (decode_field ~default:Policy_rules.default_warning_terms "terms"
               term fields) (fun terms ->
              Result.bind
                (decode_field ~default:[] "allowedContexts" context fields)
                (fun allowed_contexts ->
                  Policy_rules.warning_policy ~terms ~allowed_contexts)))
  | _ -> Error "warningComments must be an object."
