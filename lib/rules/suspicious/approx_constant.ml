let metadata =
  Rule_metadata.
    {
      id = "approx-constant";
      category = Suspicious;
      enabled_by_default = false;
    }

let constants =
  [
    ("e", 2.718281828459045);
    ("ln2", 0.6931471805599453);
    ("ln10", 2.302585092994046);
    ("log2e", 1.4426950408889634);
    ("log10e", 0.4342944819032518);
    ("pi", 3.141592653589793);
    ("sqrt1_2", 0.7071067811865476);
    ("sqrt2", 1.4142135623730951);
  ]

let approximate value =
  List.find_opt
    (fun (_, constant) -> Float.abs (Float.abs value -. constant) <= 0.000005)
    constants
  |> Option.map (fun (name, _) ->
      let sign = if value < 0. then "the negative of " else "" in
      "This literal approximates " ^ sign ^ "Math.Constants." ^ name ^ ".")

let approximate_constant (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_constant (Pconst_float (value, None)) ->
      Option.bind (Float.of_string_opt value) approximate
  | _ -> None

let inspect expression =
  Option.map
    (fun message -> ("approx-constant", message))
    (approximate_constant expression)
