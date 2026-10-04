type t = Any | Named of string list list
type error = { location : Location.t; message : string }

let rec path = function
  | Longident.Lident name -> Some [ name ]
  | Ldot (parent, name) ->
      Option.map (fun names -> names @ [ name ]) (path parent)
  | Lapply _ -> None

let is_throws ((name : string Location.loc), _) =
  name.txt = "throws" || name.txt = "raises"

let invalid location =
  Error
    {
      location;
      message =
        "Unsupported throws annotation. Use @throws, @throws(Exception), or \
         @throws([ExceptionA, ExceptionB]).";
    }

let rec names (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_construct (name, None) -> (
      match path name.txt with
      | Some path -> Ok [ path ]
      | None -> invalid name.loc)
  | Pexp_array (_ :: _ as items) | Pexp_tuple (_ :: _ as items) ->
      List.fold_left
        (fun result item ->
          Result.bind result (fun previous ->
              Result.map (List.append previous) (names item)))
        (Ok []) items
  | _ -> invalid expression.pexp_loc

let annotation ((name : string Location.loc), payload) =
  match payload with
  | Parsetree.PStr [] -> Ok Any
  | PStr [ { pstr_desc = Pstr_eval (expression, _); _ } ] ->
      Result.map (fun names -> Named names) (names expression)
  | _ -> invalid name.loc

let merge previous next =
  match (previous, next) with
  | None, value -> Some value
  | Some Any, _ | _, Any -> Some Any
  | Some (Named left), Named right ->
      Some (Named (List.sort_uniq compare (left @ right)))

let decode attributes =
  List.filter is_throws attributes
  |> List.fold_left
       (fun result attribute ->
         Result.bind result (fun previous ->
             Result.map (merge previous) (annotation attribute)))
       (Ok None)
