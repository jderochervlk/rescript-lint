open Semantic_model

let rule_ids =
  [
    "no-self-compare";
    "no-unintended-shallow-equality";
    "no-expensive-deep-equality";
    "no-float-equality";
    "prefer-pattern-check";
    "prefer-empty-check";
    "no-partial-function";
    "no-dynamic-code";
    "no-shared-array-initializer";
    "no-floating-promise";
    "require-await";
    "no-await-in-loop";
    "only-used-in-recursion";
    "eta-reduction";
    "no-ignored-result";
    "fuse-collection-pipeline";
    "no-accumulating-concat";
    "no-top-level-side-effect";
    "no-redundant-mutual-recursion";
    "prefer-standard-combinator";
  ]

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

let pattern_check report scope expression operator left right =
  let check value pattern =
    match (infer scope value, (unwrap pattern).pexp_desc) with
    | (List _ | Variant true), Pexp_construct (_, Some _)
      when literal_pattern pattern ->
        report.emit "prefer-pattern-check"
          "Use a constructor pattern to test this fixed compound shape without \
           deep equality."
          expression.Parsetree.pexp_loc
    | _ -> ()
  in
  if List.mem operator [ "=="; "!=" ] then (
    check left right;
    check right left)

let equality report context scope expression operator left right =
  let left_type, right_type = (infer scope left, infer scope right) in
  let location = expression.Parsetree.pexp_loc in
  if same_value scope left right && stable scope left then
    if left_type = Unknown then
      report.boundary "no-self-compare"
        "The value type is needed to distinguish an intentional float NaN test."
        location
    else
      report.emit "no-self-compare"
        (if left_type = Float then
           "This float is compared with itself; use an explicit NaN predicate \
            when testing NaN."
         else "This stable value is compared with itself.")
        location;
  if
    List.mem operator [ "==="; "!==" ]
    && not (has_attribute "lint.identity" expression.pexp_attributes)
  then
    if
      (compound left_type && not (literal left))
      || (compound right_type && not (literal right))
    then
      report.emit "no-unintended-shallow-equality"
        "This comparison tests compound value identity; use value equality or \
         annotate intentional identity with @lint.identity."
        location
    else if left_type = Unknown || right_type = Unknown then
      report.boundary "no-unintended-shallow-equality"
        "Operand types are required to distinguish identity from primitive \
         equality."
        location;
  if
    List.mem operator [ "=="; "!=" ]
    && max (risk left_type) (risk right_type) >= context.deep_equality_threshold
  then
    report.emit "no-expensive-deep-equality"
      "This compound value comparison may traverse a large value graph; \
       compare the relevant fields explicitly."
      location;
  if
    List.mem operator [ "=="; "!=" ]
    && (left_type = Unknown || right_type = Unknown)
  then
    report.boundary "no-expensive-deep-equality"
      "Operand types are required to estimate deep-comparison risk." location;
  if
    (left_type = Float || right_type = Float)
    && (not (literal left || literal right))
    && not (has_attribute "lint.exactFloat" expression.pexp_attributes)
  then
    report.emit "no-float-equality"
      "Exact equality of computed floats is fragile; choose a tolerance scaled \
       to the values and domain."
      location;
  if
    (left_type = Unknown || right_type = Unknown)
    && not (literal left || literal right)
  then
    report.boundary "no-float-equality"
      "Operand types are required to identify computed float equality." location

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

let length_check report scope expression operator left right =
  let inspect operator length number =
    match call scope length with
    | Some (funct, [ _ ]) when empty_comparison operator (integer number) -> (
        match api scope funct with
        | Some [ "List"; "length" ] ->
            report.emit "prefer-empty-check"
              "Match list{} instead of traversing the list to compute its \
               length."
              expression.Parsetree.pexp_loc
        | Some [ (("Array" | "String") as name); "length" ] ->
            report.emit "prefer-empty-check"
              ("Use " ^ name ^ ".isEmpty for an explicit emptiness check.")
              expression.pexp_loc
        | _ -> ())
    | _ -> ()
  in
  inspect operator left right;
  inspect (invert operator) right left

let partial_alternative = function
  | [ "List"; ("headExn" | "headOrThrow") ] -> Some "List.head"
  | [ "List"; ("tailExn" | "tailOrThrow") ] -> Some "List.tail"
  | [ "List"; ("getExn" | "getOrThrow") ] -> Some "List.get"
  | [ "Option"; ("getExn" | "getOrThrow") ] ->
      Some "an explicit Some/None match"
  | [ "Result"; ("getExn" | "getOrThrow") ] -> Some "an explicit Ok/Error match"
  | _ -> None

let ignored report scope expression value =
  match infer scope value with
  | Promise _ ->
      report.emit "no-floating-promise"
        "Handle, return, or await this promise instead of explicitly \
         discarding it."
        expression.Parsetree.pexp_loc
  | Result _ ->
      report.emit "no-ignored-result"
        "Handle the Ok and Error cases instead of discarding this result."
        expression.pexp_loc
  | Unknown ->
      report.boundary "no-floating-promise"
        "The discarded expression's result type is needed to determine whether \
         it is a promise."
        expression.pexp_loc;
      report.boundary "no-ignored-result"
        "The discarded expression's result type is needed to determine whether \
         it is a must-use result."
        expression.pexp_loc
  | _ -> ()

let newly_mutable scope expression =
  match (unwrap expression).pexp_desc with
  | Pexp_array _ -> true
  | Pexp_record _ -> (
      match infer scope expression with
      | Record fields -> List.exists (fun (_, _, mutable_) -> mutable_) fields
      | _ -> false)
  | _ -> false

let shared_initializer report scope expression arguments =
  match arguments with
  | [ (_, length); (_, value) ]
    when Option.fold ~none:true
           ~some:(fun length -> length > 1)
           (integer length)
         && newly_mutable scope value ->
      report.emit "no-shared-array-initializer"
        "Every slot shares this mutable allocation; use Array.fromInitializer \
         to allocate each element separately."
        expression.Parsetree.pexp_loc
  | _ -> ()

let pure_callback scope expression = callable_pure scope expression

let fusion report scope expression name arguments =
  match (name, arguments) with
  | [ collection; "map" ], [ (_, inner); (_, outer_callback) ] -> (
      match call scope inner with
      | Some (funct, [ (_, _); (_, inner_callback) ])
        when api scope funct = Some [ collection; "map" ]
             && pure_callback scope inner_callback
             && pure_callback scope outer_callback ->
          report.emit "fuse-collection-pipeline"
            ("Compose these pure callbacks into one " ^ collection
           ^ ".map traversal.")
            expression.Parsetree.pexp_loc
      | _ -> ())
  | _ -> ()

let accumulating report scope expression name arguments =
  match (name, arguments) with
  | [ ("Array" | "List"); "reduce" ], [ _; _; (_, callback) ] -> (
      let parameters, body = function_parts callback in
      match parameters with
      | (_, accumulator) :: _ -> (
          let nested =
            List.fold_left
              (fun scope (_, pattern) -> bind_pattern scope Unknown pattern)
              scope parameters
          in
          match (binary nested body, pattern_name accumulator) with
          | Some ("++", left, _), Some name -> (
              match
                (identifier nested left, Names.find_opt name nested.values)
              with
              | Some left, Some accumulator
                when left.identity = accumulator.identity ->
                  report.emit "no-accumulating-concat"
                    "This fold repeatedly copies the growing string; collect \
                     the parts and join once."
                    expression.Parsetree.pexp_loc
              | _ -> ())
          | _ -> ())
      | [] -> ())
  | _ -> ()

let application report scope expression funct arguments =
  match api scope funct with
  | Some name ->
      Option.iter
        (fun alternative ->
          report.emit "no-partial-function"
            ("This API can fail on missing input; use " ^ alternative ^ ".")
            expression.Parsetree.pexp_loc)
        (partial_alternative name);
      (match (name, arguments) with
      | ( ( [ "Stdlib"; "ignore" ]
          | [ "Promise"; "ignore" ]
          | [ "Result"; "ignore" ] ),
          [ (_, value) ] ) ->
          ignored report scope expression value
      | [ "Array"; "make" ], _ ->
          shared_initializer report scope expression arguments
      | [ "Global"; ("eval" | "Function") ], _ ->
          report.emit "no-dynamic-code"
            "This resolved global API evaluates dynamically supplied \
             JavaScript."
            expression.pexp_loc
      | _ -> ());
      fusion report scope expression name arguments;
      accumulating report scope expression name arguments
  | None -> ()

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

let expression_rule report context scope expression =
  (match binary scope expression with
  | Some (operator, left, right) ->
      if List.mem operator [ "=="; "!="; "==="; "!==" ] then
        equality report context scope expression operator left right;
      length_check report scope expression operator left right;
      pattern_check report scope expression operator left right
  | None -> ());
  (match call scope expression with
  | Some (funct, arguments) ->
      application report scope expression funct arguments
  | None -> ());
  (match expression.Parsetree.pexp_desc with
  | Pexp_extension ({ txt = "raw" | "bs.raw" | "res.raw"; _ }, _) ->
      report.emit "no-dynamic-code"
        "Raw JavaScript bypasses the configured static-code boundary."
        expression.pexp_loc
  | _ -> ());
  function_rule report scope expression;
  loop_rule report scope expression

let binding_rule report scope flag bindings =
  Semantic_recursion.check ~emit:report.emit ~boundary:report.boundary scope
    flag bindings;
  List.iter
    (fun (binding : Parsetree.value_binding) ->
      match binding.pvb_pat.ppat_desc with
      | Ppat_any -> ignored report scope binding.pvb_expr binding.pvb_expr
      | _ -> ())
    bindings

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

let check ?(context = default_context) ~(source : Source.t) tree =
  let diagnostics = ref [] and boundaries = ref [] in
  let diagnostic rule message location =
    Diagnostic.
      {
        filename = source.filename;
        rule;
        message;
        fixes = [];
        range = Source_range.of_location ~source:source.text location;
      }
  in
  let emit rule message location =
    diagnostics := diagnostic rule message location :: !diagnostics
  in
  let boundary rule message location =
    if List.mem rule context.enabled then
      boundaries :=
        diagnostic rule ("Analysis boundary: " ^ message) location
        :: !boundaries
  in
  let report = { emit; boundary } in
  let callbacks =
    {
      Semantic_walk.nothing with
      expression = expression_rule report context;
      bindings = binding_rule report;
      initialization = top_level report context;
    }
  in
  Semantic_walk.iter callbacks (initial context) tree;
  match Source_range.sort !boundaries with
  | first :: rest -> Error (Lint_error.Analysis_errors (first, rest))
  | [] -> Ok (Source_range.sort !diagnostics)
