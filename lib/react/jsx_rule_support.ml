module M = Jsx_model

let issue name condition message = if condition then [ (name, message) ] else []

let any_prop names element =
  List.exists (fun name -> M.present name element) names

let all_absent names element =
  List.for_all (fun name -> M.absent name element) names

let handlers =
  [
    "onClick";
    "onDoubleClick";
    "onKeyDown";
    "onKeyUp";
    "onKeyPress";
    "onMouseDown";
    "onMouseUp";
  ]

let keyboard = [ "onKeyDown"; "onKeyUp"; "onKeyPress" ]

let interactive_role element =
  Option.exists (fun role -> role.M.interactive) (M.explicit_role element)

let presentation element =
  Option.exists
    (fun role -> List.mem role.M.role_name [ "none"; "presentation" ])
    (M.explicit_role element)

let known_unhidden element =
  List.for_all
    (fun name -> M.absent name element || M.bool_prop name element = Some false)
    [ "ariaHidden"; "hidden" ]

let visible element =
  known_unhidden element
  && (not (presentation element))
  && (M.absent "role" element || Option.is_some (M.string_prop "role" element))

let empty_prop name element =
  match M.prop name element with
  | M.Missing -> true
  | Value value ->
      Option.exists (fun text -> String.trim text = "") (M.string value)
  | Unknown -> false

let named_by_prop element =
  List.exists
    (fun name -> not (empty_prop name element))
    [ "ariaLabel"; "ariaLabelledby"; "title" ]

let rec child_text ~react_unshadowed expression =
  match M.of_expression expression with
  | Some element when M.intrinsic_tag element = None && not element.fragment ->
      None
  | Some element when M.hidden element -> Some ""
  | Some element -> (
      match
        (M.string_prop "ariaLabel" element, M.string_prop "alt" element)
      with
      | Some label, _ -> Some label
      | None, Some alt when M.intrinsic_tag element = Some "img" -> Some alt
      | _ ->
          if
            List.exists
              (fun name -> not (M.absent name element))
              [ "ariaLabel"; "ariaLabelledby"; "title"; "alt" ]
          then None
          else text_children ~react_unshadowed element.children)
  | None -> M.static_text ~react_unshadowed expression

and text_children ~react_unshadowed children =
  List.fold_left
    (fun result child ->
      Option.bind result (fun text ->
          Option.map
            (fun next -> text ^ " " ^ next)
            (child_text ~react_unshadowed child)))
    (Some "") children

let empty_children ~react_unshadowed element =
  match text_children ~react_unshadowed element.M.children with
  | Some text when String.trim text = "" -> empty_prop "children" element
  | _ -> M.children_content element = M.Empty

let empty_label ~react_unshadowed element =
  (not (named_by_prop element)) && empty_children ~react_unshadowed element

let normalize_words text =
  String.lowercase_ascii text
  |> String.map (function
    | '.' | ',' | '!' | '?' | ':' | ';' -> ' '
    | character -> character)
  |> M.words |> String.concat " "

let invalid_anchor element =
  match M.string_prop "href" element with
  | Some text ->
      let text = String.lowercase_ascii (String.trim text) in
      text = "" || text = "#" || String.starts_with ~prefix:"javascript:" text
  | None -> M.absent "href" element && M.present "onClick" element

let contains parent child =
  parent.M.location.loc_start.pos_cnum < child.M.location.loc_start.pos_cnum
  && parent.location.loc_end.pos_cnum > child.location.loc_end.pos_cnum

let labelable element =
  match M.intrinsic_tag element with
  | Some "input" -> M.string_prop "type_" element <> Some "hidden"
  | Some tag ->
      List.mem tag
        [ "button"; "meter"; "output"; "progress"; "select"; "textarea" ]
  | None -> false

let associated_label ~react_unshadowed elements element =
  List.exists
    (fun label ->
      M.intrinsic_tag label = Some "label"
      && (not (empty_label ~react_unshadowed label))
      && (contains label element
         ||
         match (M.string_prop "id" element, M.string_prop "htmlFor" label) with
         | Some id, Some target -> id <> "" && id = target
         | _ -> false))
    elements

let compatible_role tag role =
  match tag with
  | "li" ->
      List.mem role
        [
          "menuitem";
          "menuitemcheckbox";
          "menuitemradio";
          "option";
          "row";
          "tab";
          "treeitem";
        ]
  | "ul" | "ol" ->
      List.mem role
        [ "listbox"; "menu"; "menubar"; "radiogroup"; "tablist"; "tree" ]
  | "table" -> List.mem role [ "grid"; "treegrid" ]
  | "td" | "th" -> role = "gridcell"
  | _ -> false

let react_aria_name name =
  match String.split_on_char '-' name with
  | "aria" :: rest -> "aria" ^ String.capitalize_ascii (String.concat "" rest)
  | _ -> name

let autofill_fields =
  M.words
    "name honorific-prefix given-name additional-name family-name \
     honorific-suffix nickname username new-password current-password \
     one-time-code organization-title organization street-address \
     address-line1 address-line2 address-line3 address-level4 address-level3 \
     address-level2 address-level1 country country-name postal-code cc-name \
     cc-given-name cc-additional-name cc-family-name cc-number cc-exp \
     cc-exp-month cc-exp-year cc-csc cc-type transaction-currency \
     transaction-amount language bday bday-day bday-month bday-year sex url \
     photo tel tel-country-code tel-national tel-area-code tel-local \
     tel-local-prefix tel-local-suffix tel-extension email impp"

let contact_fields =
  List.filter
    (fun field ->
      String.starts_with ~prefix:"tel" field
      || List.mem field [ "email"; "impp" ])
    autofill_fields

let drop_section = function
  | section :: rest
    when String.starts_with ~prefix:"section-" section
         && String.length section > 8 ->
      rest
  | words -> words

let drop_address = function
  | ("shipping" | "billing") :: rest -> rest
  | words -> words

let valid_autocomplete text =
  let tokens = M.words (String.lowercase_ascii text) in
  match tokens with
  | [ "on" ] | [ "off" ] -> true
  | _ -> (
      let tokens = tokens |> drop_section |> drop_address in
      let fields, tokens =
        match tokens with
        | ("home" | "work" | "mobile" | "fax" | "pager") :: rest ->
            (contact_fields, rest)
        | _ -> (autofill_fields, tokens)
      in
      match tokens with
      | [ field ] | [ field; "webauthn" ] -> List.mem field fields
      | _ -> false)

let ascii_alpha text =
  String.length text > 0
  && String.for_all
       (function 'a' .. 'z' | 'A' .. 'Z' -> true | _ -> false)
       text

let ascii_alnum text =
  String.length text > 0
  && String.for_all
       (function 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' -> true | _ -> false)
       text

let language_codes =
  M.words
    "aa ab ae af ak am an ar as av ay az ba be bg bh bi bm bn bo br bs ca ce \
     ch co cr cs cu cv cy da de dv dz ee el en eo es et eu fa ff fi fj fo fr \
     fy ga gd gl gn gu gv ha he hi ho hr ht hu hy hz ia id ie ig ii ik io is \
     it iu ja jv ka kg ki kj kk kl km kn ko kr ks ku kv kw ky la lb lg li ln \
     lo lt lu lv mg mh mi mk ml mn mr ms mt my na nb nd ne ng nl nn no nr nv \
     ny oc oj om or os pa pi pl ps pt qu rm rn ro ru rw sa sc sd se sg si sk \
     sl sm sn so sq sr ss st su sv sw ta te tg th ti tk tl tn to tr ts tt tw \
     ty ug uk ur uz ve vi vo wa wo xh yi yo za zh zu"

let valid_language text =
  let text = String.lowercase_ascii text in
  match String.split_on_char '-' text with
  | [ "" ] -> true
  | "x" :: rest ->
      rest <> []
      && List.for_all
           (fun value -> String.length value <= 8 && ascii_alnum value)
           rest
  | first :: rest -> (
      let language =
        List.mem first language_codes
        || (String.length first = 3 && ascii_alpha first)
      in
      language
      && List.for_all
           (fun value -> String.length value <= 8 && ascii_alnum value)
           rest
      &&
      match List.rev rest with
      | [ single ] | single :: _ -> String.length single > 1
      | [] -> true)
  | [] -> false

type context = {
  react_unshadowed : bool;
  elements : M.element list;
  tag : string;
  element : M.element;
}
