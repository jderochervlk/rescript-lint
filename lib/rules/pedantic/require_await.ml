let metadata =
  Rule_metadata.
    { id = "require-await"; category = Pedantic; enabled_by_default = false }

open Semantic_model
open Semantic_rule_support

let rec contains_await expression =
  match (unwrap expression).pexp_desc with
  | Pexp_await _ -> true
  | Pexp_fun _ -> false
  | Pexp_for (_, start, finish, direction, _)
    when empty_loop start finish direction ->
      false
  | Pexp_while
      ({ pexp_desc = Pexp_construct ({ txt = Lident "false"; _ }, None); _ }, _)
    ->
      false
  | Pexp_ifthenelse
      ( { pexp_desc = Pexp_construct ({ txt = Lident "false"; _ }, None); _ },
        _,
        otherwise ) ->
      Option.fold ~none:false ~some:contains_await otherwise
  | Pexp_ifthenelse
      ( { pexp_desc = Pexp_construct ({ txt = Lident "true"; _ }, None); _ },
        yes,
        _ ) ->
      contains_await yes
  | _ ->
      let found = ref false in
      let default = Ast_iterator.default_iterator in
      let visitor =
        {
          default with
          expr = (fun _ child -> if contains_await child then found := true);
          attribute = (fun _ _ -> ());
          attributes = (fun _ _ -> ());
        }
      in
      default.expr visitor expression;
      !found

let function_rule report scope expression =
  match expression.Parsetree.pexp_desc with
  | Pexp_fun { async = true; _ }
    when not (has_attribute "lint.promiseAdapter" expression.pexp_attributes)
    -> (
      let parameters, body = function_parts expression in
      let nested =
        List.fold_left
          (fun scope (_, pattern) ->
            bind_pattern scope (pattern_type scope pattern) pattern)
          scope parameters
      in
      if not (contains_await body) then
        match infer nested body with
        | Promise _ -> ()
        | Unknown ->
            report.boundary "require-await"
              "The return type is needed to distinguish a promise adapter from \
               an async function without await."
              expression.pexp_loc
        | _ ->
            report.emit "require-await"
              "This async function has no reachable await; remove async or \
               mark an intentional promise adapter."
              expression.pexp_loc)
  | _ -> ()
