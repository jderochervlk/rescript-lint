let qualify roots members =
  List.concat_map
    (fun root -> List.map (fun member -> root @ [ member ]) members)
    roots

let standard name members =
  qualify [ [ name ]; [ "Stdlib"; name ]; [ "Stdlib_" ^ name ] ] members

let js name implementation members =
  qualify [ [ "Js"; name ]; [ implementation ] ] members

let belt name members = qualify [ [ "Belt"; name ]; [ "Belt_" ^ name ] ] members

let specialized_set family name =
  qualify
    [
      [ "Belt"; family; name ];
      [ "Belt_" ^ family; name ];
      [ "Belt_" ^ family ^ name ];
    ]
    [ "fromSortedArrayUnsafe" ]

let typed_arrays roots names =
  List.concat_map
    (fun name ->
      qualify
        (List.map (fun root -> root @ [ name ]) roots)
        [ "unsafe_get"; "unsafe_set" ])
    names

let typed_array_names =
  [
    "Int8Array";
    "Uint8Array";
    "Uint8ClampedArray";
    "Int16Array";
    "Uint16Array";
    "Int32Array";
    "Uint32Array";
    "Float32Array";
    "Float64Array";
  ]

(* Only exported APIs: .resi files hide several unsafe implementation helpers. *)
let inventory =
  List.concat
    [
      standard "Option" [ "getUnsafe" ];
      standard "Null" [ "getUnsafe" ];
      standard "Nullable" [ "getUnsafe" ];
      standard "Dict" [ "getUnsafe" ];
      standard "Object" [ "getSymbolUnsafe" ];
      standard "Array"
        [
          "getUnsafe";
          "setUnsafe";
          "unsafe_get";
          "joinUnsafe";
          "joinWithUnsafe";
          "getSymbolUnsafe";
        ];
      standard "String"
        [
          "getUnsafe";
          "charCodeAtUnsafe";
          "getSymbolUnsafe";
          "unsafeReplaceRegExpBy0";
          "unsafeReplaceRegExpBy1";
          "unsafeReplaceRegExpBy2";
          "unsafeReplaceRegExpBy3";
          "replaceRegExpBy0Unsafe";
          "replaceRegExpBy1Unsafe";
          "replaceRegExpBy2Unsafe";
          "replaceRegExpBy3Unsafe";
        ];
      js "Null" "Js_null" [ "getUnsafe" ];
      js "Undefined" "Js_undefined" [ "getUnsafe" ];
      js "Array" "Js_array" [ "unsafe_get"; "unsafe_set" ];
      js "Array2" "Js_array2" [ "unsafe_get"; "unsafe_set" ];
      js "Dict" "Js_dict" [ "unsafeGet"; "unsafeDeleteKey" ];
      js "Json" "Js_json" [ "deserializeUnsafe" ];
      js "Date" "Js_date" [ "toJSONUnsafe" ];
      js "Math" "Js_math"
        [
          "unsafe_ceil_int";
          "unsafe_ceil";
          "unsafe_floor_int";
          "unsafe_floor";
          "unsafe_round";
          "unsafe_trunc";
        ];
      js "String" "Js_string"
        [
          "unsafeReplaceBy0";
          "unsafeReplaceBy1";
          "unsafeReplaceBy2";
          "unsafeReplaceBy3";
        ];
      js "String2" "Js_string2"
        [
          "unsafeReplaceBy0";
          "unsafeReplaceBy1";
          "unsafeReplaceBy2";
          "unsafeReplaceBy3";
        ];
      js "Promise2" "Js_promise2" [ "unsafe_async"; "unsafe_await" ];
      qualify [ [ "Js" ] ]
        [ "unsafe_lt"; "unsafe_le"; "unsafe_gt"; "unsafe_ge" ];
      qualify [ [ "Js_OO" ] ] [ "unsafe_to_method" ];
      qualify [ [ "Char" ] ] [ "unsafe_chr" ];
      qualify [ [ "Pervasives" ] ] [ "__unsafe_cast"; "unsafe_char_of_int" ];
      belt "Option" [ "getUnsafe" ];
      belt "Array"
        [
          "getUnsafe";
          "setUnsafe";
          "makeUninitializedUnsafe";
          "truncateToLengthUnsafe";
          "blitUnsafe";
        ];
      belt "Set" [ "fromSortedArrayUnsafe" ];
      belt "MutableSet" [ "fromSortedArrayUnsafe" ];
      specialized_set "Set" "Int";
      specialized_set "Set" "String";
      specialized_set "Set" "Dict";
      specialized_set "MutableSet" "Int";
      specialized_set "MutableSet" "String";
      typed_arrays
        [ [ "Js"; "Typed_array" ]; [ "Js_typed_array" ] ]
        (typed_array_names @ [ "Int32_array"; "Float32_array"; "Float64_array" ]);
      typed_arrays
        [ [ "Js"; "TypedArray2" ]; [ "Js_typed_array2" ] ]
        typed_array_names;
    ]

let message names =
  if List.mem names inventory then
    Some
      ("Do not use " ^ String.concat "." names
     ^ ". Use a checked API or explicit pattern matching.")
  else None

let rule = Banned_api.{ id = "no-unsafe"; message }
