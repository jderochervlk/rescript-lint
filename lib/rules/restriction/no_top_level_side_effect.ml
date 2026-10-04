let metadata =
  Rule_metadata.
    {
      id = "no-top-level-side-effect";
      category = Restriction;
      enabled_by_default = false;
    }

open Semantic_model
open Semantic_rule_support

let rec effectful scope expression =
  match (unwrap expression).pexp_desc with
  | Pexp_fun _ -> false
  | Pexp_setfield _ | Pexp_await _ | Pexp_assert _ -> true
  | Pexp_apply _ -> (
      match call scope expression with
      | Some (funct, arguments) ->
          let called =
            match api scope funct with
            | Some [ "Console"; _ ] | Some [ "Global"; ("eval" | "Function") ]
              ->
                true
            | Some name -> partial_alternative name <> None
            | _ -> false
          in
          called
          || List.exists
               (fun (_, argument) -> effectful scope argument)
               arguments
      | None -> false)
  | Pexp_extension ({ txt = "raw" | "bs.raw" | "res.raw"; _ }, _) -> true
  | Pexp_sequence (left, right) -> effectful scope left || effectful scope right
  | Pexp_array values | Pexp_tuple values ->
      List.exists (effectful scope) values
  | Pexp_record (fields, base) ->
      List.exists (fun field -> effectful scope field.Parsetree.x) fields
      || Option.fold ~none:false ~some:(effectful scope) base
  | Pexp_construct (_, value) | Pexp_variant (_, value) ->
      Option.fold ~none:false ~some:(effectful scope) value
  | Pexp_ifthenelse
      ( { pexp_desc = Pexp_construct ({ txt = Lident "false"; _ }, None); _ },
        _,
        no ) ->
      Option.fold ~none:false ~some:(effectful scope) no
  | Pexp_ifthenelse
      ( { pexp_desc = Pexp_construct ({ txt = Lident "true"; _ }, None); _ },
        yes,
        _ ) ->
      effectful scope yes
  | Pexp_ifthenelse (condition, yes, no) ->
      effectful scope condition || effectful scope yes
      || Option.fold ~none:false ~some:(effectful scope) no
  | _ -> false

let top_level report context scope (item : Parsetree.structure_item) =
  if not context.entry_module then
    match item.pstr_desc with
    | Pstr_eval (expression, _) when effectful scope expression ->
        report.emit "no-top-level-side-effect"
          "Move this module-initialization effect into an explicit entry \
           function."
          expression.pexp_loc
    | Pstr_value (_, bindings) ->
        List.iter
          (fun (binding : Parsetree.value_binding) ->
            if effectful scope binding.pvb_expr then
              report.emit "no-top-level-side-effect"
                "This binding may execute an effect during module \
                 initialization."
                binding.pvb_expr.pexp_loc)
          bindings
    | _ -> ()
