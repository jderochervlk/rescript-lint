let metadata =
  Rule_metadata.
    { id = "eta-reduction"; category = Style; enabled_by_default = false }

open Semantic_model
open Recursion_rule_support

let eta ~emit ~boundary scope (binding : Parsetree.value_binding) =
  let parameters, body = function_parts binding.pvb_expr in
  let nested = parameter_scope scope parameters in
  let unannotated =
    binding.pvb_attributes = []
    && binding.pvb_expr.pexp_attributes = []
    && match binding.pvb_pat.ppat_desc with Ppat_var _ -> true | _ -> false
  in
  let positional =
    List.for_all
      (fun (label, pattern) ->
        label = Asttypes.Nolabel
        && (match pattern.Parsetree.ppat_desc with
          | Ppat_var _ -> true
          | _ -> false)
        && pattern.ppat_attributes = [])
      parameters
  in
  let async =
    match (unwrap binding.pvb_expr).pexp_desc with
    | Pexp_fun { async; _ } -> async
    | _ -> false
  in
  match body.Parsetree.pexp_desc with
  | Pexp_apply { funct; args; partial = false; _ }
    when parameters <> [] && unannotated && positional && (not async)
         && List.length parameters = List.length args -> (
      let forwarded =
        List.for_all2
          (fun (_, pattern) (label, argument) ->
            label = Asttypes.Nolabel
            && argument.Parsetree.pexp_attributes = []
            &&
            match (pattern_name pattern, value_reference nested argument) with
            | Some name, Some value ->
                Option.fold ~none:false
                  ~some:(fun parameter -> parameter.identity = value.identity)
                  (Names.find_opt name nested.values)
            | _ -> false)
          parameters args
      in
      if forwarded then
        match value_reference nested funct with
        | Some { typ = Function (arguments, _); attributes = []; api; _ }
          when List.length arguments = List.length parameters
               && (match api with Some [ "Stdlib"; _ ] -> false | _ -> true)
               && List.for_all
                    (fun (label, _) -> label = Asttypes.Nolabel)
                    arguments ->
            emit "eta-reduction"
              "This wrapper forwards each positional argument unchanged to a \
               function with the same arity; bind the function directly."
              binding.pvb_loc
        | Some { typ = Unknown; _ } ->
            boundary "eta-reduction"
              "The callee's complete function arity is required before \
               reducing this wrapper."
              binding.pvb_loc
        | _ -> ())
  | _ -> ()
