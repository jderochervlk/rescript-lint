open Semantic_model

type report = {
  emit : string -> string -> Location.t -> unit;
  boundary : string -> string -> Location.t -> unit;
}

let api scope expression =
  match (unwrap expression).pexp_desc with
  | Pexp_ident name ->
      Option.bind (resolve scope name.txt) (fun value -> value.api)
  | _ -> None

let call = Semantic_model.application

let binary scope expression =
  match call scope expression with
  | Some (funct, [ (_, left); (_, right) ]) -> (
      match api scope funct with
      | Some [ "Stdlib"; name ] -> Some (name, left, right)
      | _ -> None)
  | _ -> None

let identifier scope expression =
  match (unwrap expression).pexp_desc with
  | Pexp_ident name -> resolve scope name.txt
  | _ -> None

let same_value scope left right =
  match (identifier scope left, identifier scope right) with
  | Some left, Some right -> left.identity = right.identity
  | _ -> false

let rec compound = function
  | Array _ | List _ | Record _ | Tuple _ | Variant true | Regexp | Result _ ->
      true
  | Option value -> compound value
  | _ -> false

let rec risk = function
  | Array _ | List _ -> 5
  | Record fields ->
      1 + List.fold_left (fun total (_, typ, _) -> total + risk typ) 0 fields
  | Tuple values ->
      1 + List.fold_left (fun total typ -> total + risk typ) 0 values
  | Option value | Result value -> 1 + risk value
  | Variant true -> 5
  | _ -> 1

let literal expression =
  match (unwrap expression).pexp_desc with
  | Pexp_constant _ | Pexp_construct (_, None) -> true
  | _ -> false

let rec literal_pattern expression =
  match (unwrap expression).pexp_desc with
  | Pexp_constant _ | Pexp_construct (_, None) -> true
  | Pexp_construct (_, Some value) -> literal_pattern value
  | Pexp_tuple values -> List.for_all literal_pattern values
  | _ -> false

let integer expression =
  match (unwrap expression).pexp_desc with
  | Pexp_constant (Pconst_integer (value, None)) -> int_of_string_opt value
  | _ -> None

let empty_comparison operator number =
  match (operator, number) with
  | ("==" | "===" | "!=" | "!==" | ">" | "<="), Some 0 -> true
  | ("<" | ">="), Some 1 -> true
  | _ -> false

let invert = function
  | ">" -> "<"
  | "<" -> ">"
  | ">=" -> "<="
  | "<=" -> ">="
  | name -> name

let empty_loop start finish direction =
  match (integer start, integer finish, direction) with
  | Some start, Some finish, Asttypes.Upto -> start > finish
  | Some start, Some finish, Downto -> start < finish
  | _ -> false

let partial_alternative = function
  | [ "List"; ("headExn" | "headOrThrow") ] -> Some "List.head"
  | [ "List"; ("tailExn" | "tailOrThrow") ] -> Some "List.tail"
  | [ "List"; ("getExn" | "getOrThrow") ] -> Some "List.get"
  | [ "Option"; ("getExn" | "getOrThrow") ] ->
      Some "an explicit Some/None match"
  | [ "Result"; ("getExn" | "getOrThrow") ] -> Some "an explicit Ok/Error match"
  | _ -> None

let newly_mutable scope expression =
  match (unwrap expression).pexp_desc with
  | Pexp_array _ -> true
  | Pexp_record _ -> (
      match infer scope expression with
      | Record fields -> List.exists (fun (_, _, mutable_) -> mutable_) fields
      | _ -> false)
  | _ -> false

let pure_callback scope expression = callable_pure scope expression
