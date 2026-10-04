open Rescript_linter
open Parsetree

let rec bound_names pattern =
  match pattern.ppat_desc with
  | Ppat_var name -> [ [ name.txt ] ]
  | Ppat_constraint (pattern, _) -> bound_names pattern
  | _ -> []

let rec structure_exports items = List.concat_map structure_item_exports items

and structure_item_exports item =
  match item.pstr_desc with
  | Pstr_primitive value -> [ [ value.pval_name.txt ] ]
  | Pstr_value (_, bindings) ->
      List.concat_map (fun binding -> bound_names binding.pvb_pat) bindings
  | Pstr_module binding ->
      List.map
        (fun path -> binding.pmb_name.txt :: path)
        (module_exports binding.pmb_expr)
  | _ -> []

and module_exports expression =
  match expression.pmod_desc with
  | Pmod_structure items -> structure_exports items
  | Pmod_constraint (expression, _) -> module_exports expression
  | _ -> []

let exports = function
  | Parser.Implementation items -> structure_exports items
  | Interface items ->
      List.filter_map
        (fun item ->
          match item.psig_desc with
          | Psig_value value -> Some [ value.pval_name.txt ]
          | _ -> None)
        items

let unsafe_name path =
  let name =
    match List.rev path with
    | [] -> ""
    | name :: _ -> String.lowercase_ascii name
  in
  let rec contains offset =
    offset + 6 <= String.length name
    && (String.sub name offset 6 = "unsafe" || contains (offset + 1))
  in
  contains 0

let inspect_member filename roots member =
  List.filter_map
    (fun root ->
      let path = root @ member in
      let banned = Option.is_some (No_unsafe.rule.message path) in
      if banned = unsafe_name member then None
      else
        Some
          (filename ^ ": incorrect classification of " ^ String.concat "." path))
    roots

let inspect (filename, roots) =
  let path = "../vendor/rescript/packages/@rescript/runtime/" ^ filename in
  match Result.bind (Source.read path) Parser.parse with
  | Error error -> [ Lint_error.render error ]
  | Ok tree ->
      let members = exports tree |> List.sort_uniq compare in
      if not (List.exists unsafe_name members) then
        [ filename ^ ": no unsafe exports found" ]
      else List.concat_map (inspect_member filename roots) members

let standard name extension =
  ( "Stdlib_" ^ name ^ extension,
    [ [ name ]; [ "Stdlib"; name ]; [ "Stdlib_" ^ name ] ] )

let js name implementation extension =
  (implementation ^ extension, [ [ "Js"; name ]; [ implementation ] ])

let belt name =
  ("Belt_" ^ name ^ ".resi", [ [ "Belt"; name ]; [ "Belt_" ^ name ] ])

let specialized_set family name =
  ( "Belt_" ^ family ^ name ^ ".resi",
    [
      [ "Belt"; family; name ];
      [ "Belt_" ^ family; name ];
      [ "Belt_" ^ family ^ name ];
    ] )

(* Expected members come from upstream ASTs, independently of the rule's inventory. *)
let sources =
  [
    standard "Option" ".resi";
    standard "Null" ".resi";
    standard "Nullable" ".resi";
    standard "Array" ".resi";
    standard "String" ".resi";
    standard "Dict" ".resi";
    standard "Object" ".res";
    js "Null" "Js_null" ".resi";
    js "Undefined" "Js_undefined" ".resi";
    js "Array" "Js_array" ".res";
    js "Array2" "Js_array2" ".res";
    js "Dict" "Js_dict" ".resi";
    js "Json" "Js_json" ".resi";
    js "Date" "Js_date" ".res";
    js "Math" "Js_math" ".res";
    js "String" "Js_string" ".res";
    js "String2" "Js_string2" ".res";
    js "Promise2" "Js_promise2" ".resi";
    js "Typed_array" "Js_typed_array" ".res";
    js "TypedArray2" "Js_typed_array2" ".res";
    ("Js.res", [ [ "Js" ] ]);
    ("Js_OO.res", [ [ "Js_OO" ] ]);
    ("Char.resi", [ [ "Char" ] ]);
    ("Pervasives.res", [ [ "Pervasives" ] ]);
    belt "Option";
    belt "Array";
    belt "Set";
    belt "MutableSet";
    specialized_set "Set" "Int";
    specialized_set "Set" "String";
    specialized_set "Set" "Dict";
    specialized_set "MutableSet" "Int";
    specialized_set "MutableSet" "String";
  ]

let () =
  let failures = List.concat_map inspect sources in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
