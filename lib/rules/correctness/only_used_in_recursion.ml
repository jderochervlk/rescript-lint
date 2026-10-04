let metadata =
  Rule_metadata.
    {
      id = "only-used-in-recursion";
      category = Correctness;
      enabled_by_default = false;
    }

open Semantic_model
open Recursion_rule_support

let parameter_forwarding ~emit scope (binding : Parsetree.value_binding) =
  match pattern_name binding.pvb_pat with
  | None -> ()
  | Some name ->
      let parameters, body = function_parts binding.pvb_expr in
      let nested = parameter_scope scope parameters in
      let target =
        Option.map
          (fun value -> value.identity)
          (Names.find_opt name scope.values)
      in
      let references = ref [] and forwarded = ref [] in
      let inspect current (expression : Parsetree.expression) =
        (match reference_identity current expression with
        | Some identity ->
            references := (identity, expression.pexp_loc) :: !references
        | None -> ());
        match expression.pexp_desc with
        | Pexp_apply { funct; args; partial = false; _ }
          when reference_identity current funct = target
               && target <> None
               && List.length args = List.length parameters ->
            List.iter2
              (fun (parameter_label, parameter) (argument_label, argument) ->
                match
                  (pattern_name parameter, reference_identity current argument)
                with
                | Some name, Some identity when parameter_label = argument_label
                  -> (
                    match Names.find_opt name nested.values with
                    | Some parameter when parameter.identity = identity ->
                        forwarded := argument.pexp_loc :: !forwarded
                    | _ -> ())
                | _ -> ())
              parameters args
        | _ -> ()
      in
      inspect_body nested body inspect;
      List.iter
        (fun (_, pattern) ->
          match pattern_name pattern with
          | None -> ()
          | Some name -> (
              match Names.find_opt name nested.values with
              | Some value ->
                  let uses =
                    List.filter
                      (fun (identity, _) -> identity = value.identity)
                      !references
                  in
                  if
                    uses <> []
                    && List.for_all
                         (fun (_, location) -> List.mem location !forwarded)
                         uses
                  then
                    emit "only-used-in-recursion"
                      ("Parameter " ^ name
                     ^ " is only forwarded unchanged to this recursive \
                        function.")
                      pattern.ppat_loc
              | None -> ()))
        parameters
