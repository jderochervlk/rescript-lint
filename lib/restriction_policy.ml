type entry = {
  kind : Diagnostic.symbol_kind;
  path : string;
  help : Diagnostic.help option;
}

type t = entry list

let empty = []
let is_empty entries = entries = []

let nonempty = function
  | `String text when String.trim text <> "" -> Ok text
  | _ -> Error "Expected a nonempty string."

let kind = function
  | `String "module" -> Ok Diagnostic.Module
  | `String "value" -> Ok Diagnostic.Value
  | `String "type" -> Ok Diagnostic.Type
  | _ -> Error "Restriction kind must be module, value, or type."

let identifier_start = function
  | 'a' .. 'z' | 'A' .. 'Z' | '_' -> true
  | _ -> false

let identifier_character = function
  | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '\'' -> true
  | _ -> false

let path value =
  Result.bind (nonempty value) (fun text ->
      let component value =
        String.length value > 0
        && identifier_start value.[0]
        && String.for_all identifier_character value
      in
      if List.for_all component (String.split_on_char '.' text) then Ok text
      else Error "Restriction paths must be dotted identifiers.")

let url = function
  | `String url
    when String.starts_with ~prefix:"https://" url
         || String.starts_with ~prefix:"http://" url ->
      Ok url
  | _ -> Error "Restriction URLs must use http:// or https://."

let help fields =
  match (List.assoc_opt "message" fields, List.assoc_opt "url" fields) with
  | None, None -> Ok None
  | None, Some _ -> Error "Restriction url requires a message."
  | Some message, link ->
      Result.bind (nonempty message) (fun message ->
          let link =
            match link with
            | None -> Ok None
            | Some value -> Result.map Option.some (url value)
          in
          Result.map (fun url -> Some Diagnostic.{ message; url }) link)

let entry = function
  | `Assoc fields ->
      let keys = List.map fst fields in
      if
        List.length keys <> List.length (List.sort_uniq String.compare keys)
        || List.exists
             (fun key ->
               not (List.mem key [ "kind"; "path"; "message"; "url" ]))
             keys
      then Error "Restrictions reject duplicate and unknown properties."
      else
        let get key = Option.value ~default:`Null (List.assoc_opt key fields) in
        Result.bind
          (kind (get "kind"))
          (fun kind ->
            Result.bind
              (path (get "path"))
              (fun path ->
                Result.map (fun help -> { kind; path; help }) (help fields)))
  | _ -> Error "Every restriction must be an object."

let decode = function
  | `List values ->
      List.fold_left
        (fun result value ->
          Result.bind result (fun entries ->
              Result.map (fun entry -> entry :: entries) (entry value)))
        (Ok []) values
      |> Result.map List.rev
  | _ -> Error "restrictions must be an array."

let encode entries =
  `List
    (List.map
       (fun entry ->
         `Assoc
           ([
              ("kind", `String (Diagnostic.kind_name entry.kind));
              ("path", `String entry.path);
            ]
           @ Option.fold ~none:[]
               ~some:(fun (help : Diagnostic.help) ->
                 [ ("message", `String help.message) ]
                 @ Option.fold ~none:[]
                     ~some:(fun url -> [ ("url", `String url) ])
                     help.url)
               entry.help))
       entries)

let score ~kind ~path entry =
  if
    entry.kind = Diagnostic.Module
    && (path = entry.path || String.starts_with ~prefix:(entry.path ^ ".") path)
  then Some (0, String.length entry.path)
  else if entry.kind = kind && entry.path = path then Some (1, 0)
  else None

let matching ~legacy entries ~kind ~path =
  let entries =
    entries
    @ List.map
        (fun path -> { kind = Diagnostic.Module; path; help = None })
        legacy
  in
  List.fold_left
    (fun best entry ->
      match (score ~kind ~path entry, best) with
      | None, _ -> best
      | Some score, Some (previous, _) when score <= previous -> best
      | Some score, _ -> Some (score, entry))
    None entries
  |> Option.map snd

let guidance entry = entry.help
