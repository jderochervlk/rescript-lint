module M = Jsx_model

let names =
  [
    "alt-text";
    "anchor-ambiguous-text";
    "anchor-has-content";
    "anchor-is-valid";
    "aria-activedescendant-has-tabindex";
    "aria-role";
    "aria-unsupported-elements";
    "autocomplete-valid";
    "click-events-have-key-events";
    "control-has-associated-label";
    "heading-has-content";
    "html-has-lang";
    "iframe-has-title";
    "img-redundant-alt";
    "interactive-supports-focus";
    "label-has-associated-control";
    "lang";
    "media-has-caption";
    "mouse-events-have-key-events";
    "no-access-key";
    "no-aria-hidden-on-focusable";
    "no-autofocus";
    "no-distracting-elements";
    "no-interactive-element-to-noninteractive-role";
    "no-noninteractive-element-interactions";
    "no-noninteractive-element-to-interactive-role";
    "no-noninteractive-tabindex";
    "no-redundant-roles";
    "no-static-element-interactions";
    "prefer-tag-over-role";
    "role-has-required-aria-props";
    "role-supports-aria-props";
    "scope";
    "tabindex-no-positive";
  ]

let rule_ids = List.map (fun name -> "jsx-a11y/" ^ name) names
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

let alt_checks tag element =
  let missing_alt = empty_prop "alt" element && not (named_by_prop element) in
  let required =
    match tag with
    | "img" -> M.absent "alt" element && not (named_by_prop element)
    | "area" -> missing_alt
    | "input" -> M.string_prop "type_" element = Some "image" && missing_alt
    | "object" -> missing_alt && M.children_content element = M.Empty
    | _ -> false
  in
  let redundant =
    match M.string_prop "alt" element with
    | Some text ->
        List.exists
          (fun word -> List.mem word [ "image"; "picture"; "photo" ])
          (M.words (normalize_words text))
    | None -> false
  in
  issue "alt-text" required "Provide a text alternative for this element."
  @ issue "img-redundant-alt"
      (tag = "img" && redundant)
      "Describe the image without redundant image, picture, or photo wording."

let content_checks ~react_unshadowed tag element =
  let empty = empty_label ~react_unshadowed element in
  let ambiguous =
    match text_children ~react_unshadowed element.M.children with
    | Some text ->
        List.mem (normalize_words text)
          [ "click here"; "here"; "link"; "more"; "read more"; "learn more" ]
    | None -> false
  in
  issue "anchor-has-content"
    (tag = "a" && empty && visible element)
    "Give this link accessible content."
  @ issue "anchor-ambiguous-text"
      (tag = "a" && ambiguous && not (named_by_prop element))
      "Use link text that describes its destination."
  @ issue "anchor-is-valid"
      (tag = "a" && invalid_anchor element)
      "Use a navigable href, or a button for an action."
  @ issue "heading-has-content"
      (List.mem tag [ "h1"; "h2"; "h3"; "h4"; "h5"; "h6" ]
      && empty && visible element)
      "Give this heading accessible content."
  @ issue "html-has-lang"
      (tag = "html" && empty_prop "lang" element)
      "Declare the document language with lang."
  @ issue "iframe-has-title"
      (tag = "iframe" && empty_prop "title" element)
      "Give this frame a descriptive title."

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

let labels_checks ~react_unshadowed elements tag element =
  let control =
    List.mem tag [ "button"; "input"; "select"; "textarea" ]
    && not
         (tag = "input"
         && List.mem
              (M.string_prop "type_" element)
              [
                Some "hidden";
                Some "submit";
                Some "reset";
                Some "button";
                Some "image";
              ])
  in
  let nested_control =
    List.exists
      (fun child -> contains element child && labelable child)
      elements
  in
  issue "control-has-associated-label"
    (control && visible element
    && empty_label ~react_unshadowed element
    && not (associated_label ~react_unshadowed elements element))
    "Associate this control with a label or accessible name."
  @ issue "label-has-associated-control"
      (tag = "label"
      && empty_prop "htmlFor" element
      && (not nested_control) && not element.M.spread)
      "Associate this label using htmlFor or a nested control."

let static_checks tag element =
  issue "no-access-key"
    (M.present "accessKey" element)
    "Avoid accessKey because it conflicts with assistive keyboard shortcuts."
  @ issue "no-autofocus"
      (M.bool_prop "autoFocus" element = Some true)
      "Avoid moving focus automatically."
  @ issue "no-distracting-elements"
      (List.mem tag [ "marquee"; "blink" ])
      "Replace this distracting element with ordinary content."
  @ issue "scope"
      (tag <> "th" && M.present "scope" element)
      "Use scope only on table header cells."
  @ issue "tabindex-no-positive"
      (Option.exists (fun value -> value > 0) (M.int_prop "tabIndex" element))
      "Use natural focus order instead of a positive tabIndex."
  @ issue "no-aria-hidden-on-focusable"
      (M.bool_prop "ariaHidden" element = Some true
      && M.focusable element = Some true)
      "Do not hide a focusable element from the accessibility tree."

let interaction_checks element =
  let inactive = M.native_interactive element = Some false in
  let exposed =
    visible element && M.bool_prop "contentEditable" element <> Some true
  in
  let interacts = any_prop handlers element in
  let lacks_role = M.absent "role" element in
  issue "click-events-have-key-events"
    (exposed && inactive
    && M.present "onClick" element
    && all_absent keyboard element)
    "Provide keyboard activation alongside this click handler."
  @ issue "mouse-events-have-key-events"
      (any_prop [ "onMouseOver"; "onMouseEnter" ] element
       && M.absent "onFocus" element
      || any_prop [ "onMouseOut"; "onMouseLeave" ] element
         && M.absent "onBlur" element)
      "Pair mouse enter/leave handlers with focus/blur handlers."
  @ issue "interactive-supports-focus"
      (exposed && interacts && interactive_role element
      && M.focusable element = Some false)
      "Make this interactive role focusable."
  @ issue "aria-activedescendant-has-tabindex"
      (M.present "ariaActivedescendant" element
      && M.focusable element = Some false)
      "Make the active-descendant owner focusable."
  @ issue "no-noninteractive-element-interactions"
      (exposed && inactive && interacts && lacks_role)
      "Use an interactive element for these interaction handlers."
  @ issue "no-static-element-interactions"
      (exposed && inactive && interacts && lacks_role
      && M.implicit_role element = None)
      "Give this interactive element appropriate semantics."
  @ issue "no-noninteractive-tabindex"
      (inactive
      && (M.absent "role" element || Option.is_some (M.explicit_role element))
      && (not (interactive_role element))
      && Option.exists (fun index -> index >= 0) (M.int_prop "tabIndex" element)
      )
      "Avoid tab stops on noninteractive elements."

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

let role_transition_checks tag element role =
  let implicit = M.implicit_role element in
  let semantic_noninteractive =
    Option.exists
      (fun name ->
        Option.exists (fun role -> not role.M.interactive) (M.find_role name))
      implicit
  in
  let redundant =
    implicit = Some role.M.role_name
    || (implicit = Some "presentation" && role.role_name = "none")
  in
  issue "no-interactive-element-to-noninteractive-role"
    (M.native_interactive element = Some true && not role.interactive)
    "Keep the native interactive semantics of this element."
  @ issue "no-noninteractive-element-to-interactive-role"
      (semantic_noninteractive && role.interactive
      && not (compatible_role tag role.role_name))
      "Use a native interactive element inside this semantic element."
  @ issue "no-redundant-roles" redundant
      "This role repeats the element's native semantics."
  @ issue "prefer-tag-over-role"
      ((not redundant) && Option.is_some (M.native_tag role.role_name))
      ("Prefer the native element for the " ^ role.role_name ^ " role.")

let react_aria_name name =
  match String.split_on_char '-' name with
  | "aria" :: rest -> "aria" ^ String.capitalize_ascii (String.concat "" rest)
  | _ -> name

let role_property_checks element role =
  let native = M.implicit_role element = Some role.M.role_name in
  let missing =
    if native then []
    else
      List.filter
        (fun name -> M.absent (react_aria_name name) element)
        role.required
  in
  let unsupported =
    List.filter_map
      (fun (property : M.property) ->
        if property.optional || not (M.present property.name element) then None
        else
          Option.bind (M.aria_name property.name) (fun name ->
              if
                List.mem name role.prohibited
                || not (List.mem name role.supported)
              then Some name
              else None))
      element.M.props
  in
  issue "role-has-required-aria-props" (missing <> [])
    ("This role requires " ^ String.concat ", " missing ^ ".")
  @ issue "role-supports-aria-props" (unsupported <> [])
      ("This role does not support " ^ String.concat ", " unsupported ^ ".")

let role_checks tag element =
  let invalid =
    Option.exists
      (fun _ -> M.explicit_role element = None)
      (M.string_prop "role" element)
  in
  let aria =
    List.exists
      (fun (property : M.property) ->
        Option.is_some (M.aria_name property.name))
      element.M.props
  in
  issue "aria-role" invalid "Use a concrete supported ARIA role."
  @ issue "aria-unsupported-elements"
      (List.mem tag
         [ "base"; "head"; "link"; "meta"; "param"; "script"; "style"; "title" ]
      && (aria || M.present "role" element))
      "This metadata element does not support ARIA semantics."
  @ Option.fold
      ~none:
        (if M.absent "role" element then
           Option.fold ~none:[]
             ~some:(role_property_checks element)
             (Option.bind (M.implicit_role element) M.find_role)
         else [])
      ~some:(fun role ->
        role_transition_checks tag element role
        @ role_property_checks element role)
      (M.explicit_role element)

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

let value_checks tag element =
  issue "autocomplete-valid"
    (List.mem tag [ "input"; "select"; "textarea" ]
    && Option.exists
         (fun text -> not (valid_autocomplete text))
         (M.string_prop "autoComplete" element))
    "Use a valid HTML autocomplete token sequence."
  @ issue "lang"
      (Option.exists
         (fun text -> not (valid_language text))
         (M.string_prop "lang" element))
      "Use a valid language tag, such as en or en-US."

let media_checks elements tag element =
  let descendants = List.filter (contains element) elements in
  let track =
    List.exists
      (fun child ->
        M.intrinsic_tag child = Some "track"
        && M.string_prop "kind" child = Some "captions")
      descendants
  in
  let uncertain =
    List.exists
      (fun child ->
        M.intrinsic_tag child = None
        || child.M.spread
        || M.intrinsic_tag child = Some "track"
           && (not (M.absent "kind" child))
           && M.string_prop "kind" child = None)
      descendants
    || List.exists
         (fun child -> M.of_expression child = None)
         element.M.children
  in
  issue "media-has-caption"
    (List.mem tag [ "audio"; "video" ]
    && M.bool_prop "muted" element <> Some true
    && visible element && (not track) && (not uncertain) && not element.spread)
    "Provide a captions track for this media."

let inspect ~react_unshadowed elements tag element =
  alt_checks tag element
  @ content_checks ~react_unshadowed tag element
  @ labels_checks ~react_unshadowed elements tag element
  @ static_checks tag element @ interaction_checks element
  @ role_checks tag element @ value_checks tag element
  @ media_checks elements tag element

let visibility_rules =
  [
    "anchor-has-content";
    "anchor-ambiguous-text";
    "heading-has-content";
    "control-has-associated-label";
    "click-events-have-key-events";
    "interactive-supports-focus";
    "no-noninteractive-element-interactions";
    "no-static-element-interactions";
    "media-has-caption";
  ]

let exposed_in elements element =
  visible element
  && not
       (List.exists
          (fun ancestor ->
            contains ancestor element
            && M.intrinsic_tag ancestor <> None
            && not (known_unhidden ancestor))
          elements)

let check ?(module_signatures = []) ~source tree =
  let elements = M.elements tree in
  let react_unshadowed = M.unshadowed_module ~module_signatures "React" tree in
  List.concat_map
    (fun element ->
      match M.intrinsic_tag element with
      | None -> []
      | Some tag ->
          inspect ~react_unshadowed elements tag element
          |> List.filter (fun (name, _) ->
              (not (List.mem name visibility_rules))
              || exposed_in elements element)
          |> List.map (fun (name, message) ->
              M.emit ~source ("jsx-a11y/" ^ name) message element.M.location))
    elements
  |> Source_range.sort
