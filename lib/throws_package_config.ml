type directory = { path : string; recursive : bool }

type t = {
  name : string;
  namespace : string option;
  dependencies : string list;
  directories : directory list;
}

let unique fields =
  let names = List.map fst fields in
  if List.length names = List.length (List.sort_uniq String.compare names) then
    Ok fields
  else Error "Duplicate dependency configuration properties are unsupported."

let nonempty = function
  | `String value when String.trim value <> "" -> Ok value
  | _ -> Error "Expected a nonempty string in dependency configuration."

let strings = function
  | None -> Ok []
  | Some (`List values) ->
      List.fold_left
        (fun result value ->
          Result.bind result (fun values ->
              Result.map (fun value -> values @ [ value ]) (nonempty value)))
        (Ok []) values
  | _ -> Error "Dependency names must be an array of strings."

let dependencies fields =
  match
    ( List.assoc_opt "dependencies" fields,
      List.assoc_opt "bs-dependencies" fields )
  with
  | Some _, Some _ ->
      Error "dependencies and bs-dependencies are mutually exclusive."
  | modern, legacy -> strings (match modern with None -> legacy | _ -> modern)

let module_name value =
  let valid = function
    | 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' -> true
    | _ -> false
  in
  String.length value > 0
  && (match value.[0] with 'A' .. 'Z' -> true | _ -> false)
  && String.for_all valid value

let namespace_name name =
  let _, characters =
    String.fold_left
      (fun (capitalize, characters) character ->
        match character with
        | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' ->
            ( false,
              (if capitalize then Char.uppercase_ascii character else character)
              :: characters )
        | '/' | '-' -> (true, characters)
        | _ -> (capitalize, characters))
      (true, []) name
  in
  let normalized = String.of_seq (List.to_seq (List.rev characters)) in
  if module_name normalized then Ok (Some normalized)
  else Error "The dependency namespace is not a supported ReScript module name."

let namespace fields name =
  if List.mem_assoc "namespace-entry" fields then
    Error "Dependency namespace-entry facades are not supported."
  else
    match List.assoc_opt "namespace" fields with
    | None | Some (`Bool false) -> Ok None
    | Some (`Bool true) | Some (`String "true") -> namespace_name name
    | Some (`String value) -> namespace_name value
    | _ -> Error "Dependency namespace must be a boolean or string."

let source_object fields =
  Result.bind (unique fields) (fun fields ->
      if
        List.exists
          (fun (key, _) -> not (List.mem key [ "dir"; "subdirs"; "type" ]))
          fields
      then
        Error
          "Unsupported dependency source property; expected dir, subdirs or \
           type."
      else
        match
          ( List.assoc_opt "dir" fields,
            List.assoc_opt "subdirs" fields,
            List.assoc_opt "type" fields )
        with
        | Some (`String path), (None | Some (`Bool false)), None when path <> ""
          ->
            Ok [ { path; recursive = false } ]
        | Some (`String path), Some (`Bool true), None when path <> "" ->
            Ok [ { path; recursive = true } ]
        | Some (`String path), (None | Some (`Bool _)), Some (`String "dev")
          when path <> "" ->
            Ok []
        | _ ->
            Error
              "Unsupported dependency source: use dir, boolean subdirs and \
               optional type dev.")

let source = function
  | `String path when path <> "" -> Ok [ { path; recursive = false } ]
  | `Assoc fields -> source_object fields
  | _ -> Error "Unsupported dependency source description."

let sources = function
  | None -> Error "Dependency sources must be explicitly configured."
  | Some (`List entries) ->
      List.fold_left
        (fun result entry ->
          Result.bind result (fun directories ->
              Result.map (List.append directories) (source entry)))
        (Ok []) entries
  | Some entry -> source entry

let unsupported_configuration fields =
  let nonempty_field name =
    match List.assoc_opt name fields with
    | None | Some (`List []) -> false
    | _ -> true
  in
  if
    List.exists nonempty_field
      [ "bsc-flags"; "ppx-flags"; "bs-ppx-flags"; "generators" ]
  then
    Error
      "Dependency compiler flags, PPX transforms and generators are \
       unsupported."
  else Ok ()

let decode_fields fields =
  Result.bind (unsupported_configuration fields) (fun () ->
      Result.bind
        (nonempty (Option.value ~default:`Null (List.assoc_opt "name" fields)))
        (fun name ->
          Result.bind (namespace fields name) (fun namespace ->
              Result.bind (dependencies fields) (fun dependencies ->
                  Result.map
                    (fun directories ->
                      { name; namespace; dependencies; directories })
                    (sources (List.assoc_opt "sources" fields))))))

let decode = function
  | `Assoc fields -> Result.bind (unique fields) decode_fields
  | _ -> Error "Dependency rescript.json must be an object."
