type t = { start : int; finish : int; text : string }
type error = Invalid_range | Overlapping_edits

let compare left right =
  Stdlib.compare
    (left.start, left.finish, left.text)
    (right.start, right.finish, right.text)

let apply source edits =
  let rec collect cursor pieces = function
    | [] ->
        let suffix = String.sub source cursor (String.length source - cursor) in
        Ok (String.concat "" (List.rev (suffix :: pieces)))
    | edit :: rest ->
        if
          edit.start < 0 || edit.finish < edit.start
          || edit.finish > String.length source
        then Error Invalid_range
        else if edit.start < cursor then Error Overlapping_edits
        else
          let unchanged = String.sub source cursor (edit.start - cursor) in
          collect edit.finish (edit.text :: unchanged :: pieces) rest
  in
  let edits = List.sort_uniq compare edits in
  let rec conflicting = function
    | left :: (right :: _ as rest) ->
        left.start = right.start || conflicting rest
    | _ -> false
  in
  if conflicting edits then Error Overlapping_edits else collect 0 [] edits
