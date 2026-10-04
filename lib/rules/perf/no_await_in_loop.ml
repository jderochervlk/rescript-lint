let metadata =
  Rule_metadata.
    { id = "no-await-in-loop"; category = Perf; enabled_by_default = false }

open Semantic_model
open Semantic_rule_support

let independent_await scope expression =
  match (unwrap expression).pexp_desc with
  | Pexp_await value -> (
      match call scope value with
      | Some (funct, arguments) ->
          let contract =
            match identifier scope funct with
            | Some value -> has_attribute "lint.independent" value.attributes
            | None -> false
          in
          let primitive_resolve =
            api scope funct = Some [ "Promise"; "resolve" ]
            && List.for_all
                 (fun (_, argument) ->
                   match infer scope argument with
                   | Unit | Bool | Int | Float | String -> true
                   | _ -> false)
                 arguments
          in
          (primitive_resolve || contract)
          && List.for_all (fun (_, value) -> pure scope value) arguments
      | None -> false)
  | _ -> false

let loop_rule report scope expression =
  match expression.Parsetree.pexp_desc with
  | Pexp_for (pattern, start, finish, direction, body)
    when not (empty_loop start finish direction) ->
      let scope = bind_pattern scope Int pattern in
      if independent_await scope body then
        report.emit "no-await-in-loop"
          "These explicitly independent iterations await sequentially; collect \
           the promises and await them together."
          body.pexp_loc
  | _ -> ()
