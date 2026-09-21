type property = {
  name : string;
  value : Parsetree.expression option;
  optional : bool;
  location : Location.t;
}

type element = {
  name : string list;
  props : property list;
  children : Parsetree.expression list;
  spread : bool;
  fragment : bool;
  location : Location.t;
  expression : Parsetree.expression;
}

type prop_value = Missing | Unknown | Value of Parsetree.expression
type content = Empty | Present | Dynamic

let rec path = function
  | Longident.Lident name -> [ name ]
  | Ldot (parent, name) -> path parent @ [ name ]
  | Lapply _ -> []

let tag_name = function
  | Parsetree.JsxLowerTag name -> [ name ]
  | JsxQualifiedLowerTag { path = parent; name } -> path parent @ [ name ]
  | JsxUpperTag name -> path name
  | JsxTagInvalid _ -> []

let property = function
  | Parsetree.JSXPropValue (name, optional, value) ->
      Some
        { name = name.txt; value = Some value; optional; location = name.loc }
  | JSXPropPunning (optional, name) ->
      Some { name = name.txt; value = None; optional; location = name.loc }
  | JSXPropSpreading _ -> None

let make expression name raw_props children fragment =
  {
    name;
    props = List.filter_map property raw_props;
    children;
    spread =
      List.exists
        (function Parsetree.JSXPropSpreading _ -> true | _ -> false)
        raw_props;
    fragment;
    location = expression.Parsetree.pexp_loc;
    expression;
  }

let rec of_expression (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_constraint (inner, _) -> of_expression inner
  | Pexp_jsx_element (Jsx_fragment fragment) ->
      Some (make expression [] [] fragment.jsx_fragment_children true)
  | Pexp_jsx_element (Jsx_unary_element element) ->
      Some
        (make expression
           (tag_name element.jsx_unary_element_tag_name.txt)
           element.jsx_unary_element_props [] false)
  | Pexp_jsx_element (Jsx_container_element element) ->
      Some
        (make expression
           (tag_name element.jsx_container_element_tag_name_start.txt)
           element.jsx_container_element_props
           element.jsx_container_element_children false)
  | _ -> None

let intrinsic_tag element =
  match element.expression.pexp_desc with
  | Pexp_jsx_element
      (Jsx_unary_element
         { jsx_unary_element_tag_name = { txt = JsxLowerTag name; _ }; _ })
  | Pexp_jsx_element
      (Jsx_container_element
         {
           jsx_container_element_tag_name_start = { txt = JsxLowerTag name; _ };
           _;
         }) ->
      if String.contains name '-' then None else Some name
  | _ -> None

let prop name element =
  if element.spread then Unknown
  else
    match
      List.find_opt
        (fun (property : property) -> property.name = name)
        (List.rev element.props)
    with
    | None -> Missing
    | Some { optional = true; _ } | Some { value = None; _ } -> Unknown
    | Some { value = Some value; _ } -> Value value

let present name element =
  (not element.spread)
  && List.exists
       (fun (property : property) ->
         property.name = name && not property.optional)
       element.props

let absent name element =
  match prop name element with Missing -> true | _ -> false

let rec string (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_constant (Pconst_string (value, None))
    when not (String.contains value '\\') ->
      Some value
  | Pexp_variant (value, None) -> Some value
  | Pexp_constraint (inner, _) -> string inner
  | _ -> None

let integer (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_constant (Pconst_integer (value, None)) -> int_of_string_opt value
  | _ -> None

let boolean (expression : Parsetree.expression) =
  match expression.pexp_desc with
  | Pexp_construct ({ txt = Lident "true"; _ }, None) -> Some true
  | Pexp_construct ({ txt = Lident "false"; _ }, None) -> Some false
  | _ -> (
      match string expression with
      | Some "true" -> Some true
      | Some "false" -> Some false
      | _ -> None)

let value getter name element =
  match prop name element with
  | Value expression -> getter expression
  | _ -> None

let string_prop = value string
let int_prop = value integer
let bool_prop = value boolean

let words text =
  String.map
    (function '\t' | '\n' | '\r' | '\012' -> ' ' | character -> character)
    text
  |> String.split_on_char ' '
  |> List.filter (fun value -> value <> "")

let hidden element =
  bool_prop "ariaHidden" element = Some true
  || bool_prop "hidden" element = Some true

let combine_content left right =
  match (left, right) with
  | Present, _ | _, Present -> Present
  | Dynamic, _ | _, Dynamic -> Dynamic
  | Empty, Empty -> Empty

let text_content value = if String.trim value = "" then Empty else Present

let prop_content name element =
  match prop name element with
  | Missing -> Empty
  | Unknown -> Dynamic
  | Value expression ->
      Option.fold ~none:Dynamic ~some:text_content (string expression)

let rec expression_content expression =
  match of_expression expression with
  | Some element when intrinsic_tag element = None && not element.fragment ->
      Dynamic
  | Some element when hidden element -> Empty
  | Some element -> accessible_label element
  | None -> (
      match expression.Parsetree.pexp_desc with
      | Pexp_constant (Pconst_string (text, None)) -> text_content text
      | Pexp_construct ({ txt = Lident "()"; _ }, None) -> Empty
      | _ -> Dynamic)

and children_content element =
  List.fold_left
    (fun content child -> combine_content content (expression_content child))
    (prop_content "children" element)
    element.children

and accessible_label element =
  let labels = [ "ariaLabel"; "ariaLabelledby"; "title" ] in
  let label =
    List.fold_left
      (fun content name -> combine_content content (prop_content name element))
      Empty labels
  in
  let label =
    if intrinsic_tag element = Some "img" then
      combine_content label (prop_content "alt" element)
    else label
  in
  combine_content label (children_content element)

let elements tree =
  let found = ref [] in
  let visitor =
    {
      Ast_iterator.default_iterator with
      expr =
        (fun iterator expression ->
          (match expression.Parsetree.pexp_desc with
          | Pexp_jsx_element _ ->
              Option.iter
                (fun element -> found := element :: !found)
                (of_expression expression)
          | _ -> ());
          Ast_iterator.default_iterator.expr iterator expression);
      attribute = (fun _ _ -> ());
    }
  in
  (match tree with
  | Parser.Implementation tree -> visitor.structure visitor tree
  | Interface tree -> visitor.signature visitor tree);
  List.rev !found

let signature_module name items =
  List.find_map
    (fun (item : Parsetree.signature_item) ->
      match item.psig_desc with
      | Psig_module declaration when declaration.pmd_name.txt = name -> (
          match declaration.pmd_type.pmty_desc with
          | Pmty_signature items -> Some items
          | _ -> None)
      | _ -> None)
    items

let rec nested_signature items = function
  | [] -> Some items
  | name :: rest ->
      Option.bind (signature_module name items) (fun items ->
          nested_signature items rest)

let opened_signature signatures identifier =
  match path identifier with
  | first :: rest ->
      Option.bind (List.assoc_opt first signatures) (fun items ->
          nested_signature items rest)
  | [] -> None

let exports_module name items =
  List.exists
    (fun (item : Parsetree.signature_item) ->
      match item.psig_desc with
      | Psig_module declaration -> declaration.pmd_name.txt = name
      | Psig_recmodule declarations ->
          List.exists
            (fun declaration -> declaration.Parsetree.pmd_name.txt = name)
            declarations
      | Psig_include _ -> true
      | _ -> false)
    items

let unshadowed_module ?(module_signatures = []) name tree =
  let shadowed = ref (List.mem_assoc name module_signatures) in
  let inspect_open identifier =
    if
      Option.fold ~none:true ~some:(exports_module name)
        (opened_signature module_signatures identifier)
    then shadowed := true
  in
  let visitor =
    {
      Ast_iterator.default_iterator with
      module_binding =
        (fun iterator binding ->
          if binding.Parsetree.pmb_name.txt = name then shadowed := true;
          Ast_iterator.default_iterator.module_binding iterator binding);
      expr =
        (fun iterator expression ->
          (match expression.Parsetree.pexp_desc with
          | Pexp_letmodule (bound, _, _) when bound.txt = name ->
              shadowed := true
          | Pexp_open (_, identifier, _) -> inspect_open identifier.txt
          | _ -> ());
          Ast_iterator.default_iterator.expr iterator expression);
      module_expr =
        (fun iterator expression ->
          (match expression.Parsetree.pmod_desc with
          | Pmod_functor (parameter, _, _) when parameter.txt = name ->
              shadowed := true
          | _ -> ());
          Ast_iterator.default_iterator.module_expr iterator expression);
      open_description =
        (fun _ declaration -> inspect_open declaration.Parsetree.popen_lid.txt);
      attribute = (fun _ _ -> ());
    }
  in
  (match tree with
  | Parser.Implementation tree -> visitor.structure visitor tree
  | Interface tree -> visitor.signature visitor tree);
  not !shadowed

let static_text ~react_unshadowed (expression : Parsetree.expression) =
  match string expression with
  | Some value -> Some value
  | None -> (
      match expression.pexp_desc with
      | Pexp_apply
          {
            funct = { pexp_desc = Pexp_ident name; _ };
            args = [ (Nolabel, value) ];
            partial = false;
            _;
          }
        when react_unshadowed && path name.txt = [ "React"; "string" ] ->
          string value
      | _ -> None)

let emit ~(source : Source.t) rule message location =
  Diagnostic.
    {
      filename = source.filename;
      rule;
      message;
      fixes = [];
      range = Source_range.of_location ~source:source.text location;
    }

type role = {
  role_name : string;
  required : string list;
  supported : string list;
  prohibited : string list;
  interactive : bool;
}

(* WAI-ARIA 1.2 Recommendation, 2023-06-06: role feature tables. *)
let common_aria_properties =
  words
    "aria-atomic aria-busy aria-controls aria-current aria-describedby \
     aria-details aria-disabled aria-dropeffect aria-errormessage aria-flowto \
     aria-grabbed aria-haspopup aria-hidden aria-invalid aria-keyshortcuts \
     aria-label aria-labelledby aria-live aria-owns aria-relevant \
     aria-roledescription"

let make_role role_name required supported prohibited interactive =
  {
    role_name;
    required = words required;
    supported = common_aria_properties @ words supported;
    prohibited = words prohibited;
    interactive;
  }

let roles =
  [
    make_role "alert" "" "" "" false;
    make_role "alertdialog" "" "aria-modal" "" false;
    make_role "application" "" "aria-activedescendant aria-expanded" "" false;
    make_role "article" "" "aria-posinset aria-setsize" "" false;
    make_role "banner" "" "" "" false;
    make_role "blockquote" "" "" "" false;
    make_role "button" "" "aria-expanded aria-pressed" "" true;
    make_role "caption" "" "" "aria-label aria-labelledby" false;
    make_role "cell" "" "aria-colindex aria-colspan aria-rowindex aria-rowspan"
      "" false;
    make_role "checkbox" "aria-checked"
      "aria-checked aria-expanded aria-readonly aria-required" "" true;
    make_role "code" "" "" "aria-label aria-labelledby" false;
    make_role "columnheader" ""
      "aria-colindex aria-colspan aria-expanded aria-readonly aria-required \
       aria-rowindex aria-rowspan aria-selected aria-sort"
      "" false;
    make_role "combobox" "aria-controls aria-expanded"
      "aria-activedescendant aria-autocomplete aria-expanded aria-readonly \
       aria-required"
      "" true;
    make_role "complementary" "" "" "" false;
    make_role "contentinfo" "" "" "" false;
    make_role "definition" "" "" "" false;
    make_role "deletion" "" "" "aria-label aria-labelledby" false;
    make_role "dialog" "" "aria-modal" "" false;
    make_role "directory" "" "" "" false;
    make_role "document" "" "" "" false;
    make_role "emphasis" "" "" "aria-label aria-labelledby" false;
    make_role "feed" "" "" "" false;
    make_role "figure" "" "" "" false;
    make_role "form" "" "" "" false;
    make_role "generic" "" "" "aria-label aria-labelledby aria-roledescription"
      false;
    make_role "grid" ""
      "aria-activedescendant aria-colcount aria-multiselectable aria-readonly \
       aria-rowcount"
      "" true;
    make_role "gridcell" ""
      "aria-colindex aria-colspan aria-expanded aria-readonly aria-required \
       aria-rowindex aria-rowspan aria-selected"
      "" true;
    make_role "group" "" "aria-activedescendant" "" false;
    make_role "heading" "aria-level" "aria-level" "" false;
    make_role "img" "" "" "" false;
    make_role "insertion" "" "" "aria-label aria-labelledby" false;
    make_role "link" "" "aria-expanded" "" true;
    make_role "list" "" "" "" false;
    make_role "listbox" ""
      "aria-activedescendant aria-expanded aria-multiselectable \
       aria-orientation aria-readonly aria-required"
      "" true;
    make_role "listitem" "" "aria-level aria-posinset aria-setsize" "" false;
    make_role "log" "" "" "" false;
    make_role "main" "" "" "" false;
    make_role "marquee" "" "" "" false;
    make_role "math" "" "" "" false;
    make_role "meter" "aria-valuenow"
      "aria-valuemax aria-valuemin aria-valuenow aria-valuetext" "" false;
    make_role "menu" "" "aria-activedescendant aria-orientation" "" true;
    make_role "menubar" "" "aria-activedescendant aria-orientation" "" true;
    make_role "menuitem" "" "aria-expanded aria-posinset aria-setsize" "" true;
    make_role "menuitemcheckbox" "aria-checked"
      "aria-checked aria-expanded aria-posinset aria-setsize" "" true;
    make_role "menuitemradio" ""
      "aria-checked aria-expanded aria-posinset aria-setsize" "" true;
    make_role "navigation" "" "" "" false;
    make_role "none" "" "" "" false;
    make_role "note" "" "" "" false;
    make_role "option" "aria-selected"
      "aria-checked aria-posinset aria-selected aria-setsize" "" true;
    make_role "paragraph" "" "" "aria-label aria-labelledby" false;
    make_role "presentation" "" "" "" false;
    make_role "progressbar" ""
      "aria-valuemax aria-valuemin aria-valuenow aria-valuetext" "" false;
    make_role "radio" "aria-checked" "aria-checked aria-posinset aria-setsize"
      "" true;
    make_role "radiogroup" ""
      "aria-activedescendant aria-orientation aria-readonly aria-required" ""
      true;
    make_role "region" "" "" "" false;
    make_role "row" ""
      "aria-activedescendant aria-colindex aria-expanded aria-level \
       aria-posinset aria-rowindex aria-selected aria-setsize"
      "" false;
    make_role "rowgroup" "" "" "" false;
    make_role "rowheader" ""
      "aria-colindex aria-colspan aria-expanded aria-readonly aria-required \
       aria-rowindex aria-rowspan aria-selected aria-sort"
      "" false;
    make_role "scrollbar" "aria-controls aria-valuenow"
      "aria-orientation aria-valuemax aria-valuemin aria-valuenow \
       aria-valuetext"
      "" true;
    make_role "search" "" "" "" false;
    make_role "searchbox" ""
      "aria-activedescendant aria-autocomplete aria-multiline aria-placeholder \
       aria-readonly aria-required"
      "" true;
    make_role "separator" "aria-valuenow"
      "aria-orientation aria-valuemax aria-valuemin aria-valuenow \
       aria-valuetext"
      "" false;
    make_role "slider" "aria-valuenow"
      "aria-orientation aria-readonly aria-valuemax aria-valuemin \
       aria-valuenow aria-valuetext"
      "" true;
    make_role "spinbutton" ""
      "aria-activedescendant aria-readonly aria-required aria-valuemax \
       aria-valuemin aria-valuenow aria-valuetext"
      "" true;
    make_role "status" "" "" "" false;
    make_role "strong" "" "" "aria-label aria-labelledby" false;
    make_role "subscript" "" "" "aria-label aria-labelledby" false;
    make_role "superscript" "" "" "aria-label aria-labelledby" false;
    make_role "switch" "aria-checked"
      "aria-checked aria-expanded aria-readonly aria-required" "" true;
    make_role "tab" "" "aria-expanded aria-posinset aria-selected aria-setsize"
      "" true;
    make_role "table" "" "aria-colcount aria-rowcount" "" false;
    make_role "tablist" ""
      "aria-activedescendant aria-multiselectable aria-orientation" "" true;
    make_role "tabpanel" "" "" "" false;
    make_role "term" "" "" "" false;
    make_role "textbox" ""
      "aria-activedescendant aria-autocomplete aria-multiline aria-placeholder \
       aria-readonly aria-required"
      "" true;
    make_role "time" "" "" "" false;
    make_role "timer" "" "" "" false;
    make_role "toolbar" "" "aria-activedescendant aria-orientation" "" false;
    make_role "tooltip" "" "" "" false;
    make_role "tree" ""
      "aria-activedescendant aria-multiselectable aria-orientation \
       aria-required"
      "" true;
    make_role "treegrid" ""
      "aria-activedescendant aria-colcount aria-multiselectable \
       aria-orientation aria-readonly aria-required aria-rowcount"
      "" true;
    make_role "treeitem" ""
      "aria-checked aria-expanded aria-level aria-posinset aria-selected \
       aria-setsize"
      "" true;
  ]

let find_role name = List.find_opt (fun role -> role.role_name = name) roles

let explicit_role element =
  Option.bind (string_prop "role" element) (fun text ->
      List.find_map find_role (words text))

let text_input_role fallback element =
  if present "list" element then Some "combobox"
  else if absent "list" element then Some fallback
  else None

let input_role element =
  match string_prop "type_" element with
  | Some ("button" | "submit" | "reset" | "image") -> Some "button"
  | Some "checkbox" -> Some "checkbox"
  | Some "radio" -> Some "radio"
  | Some "range" -> Some "slider"
  | Some "number" -> Some "spinbutton"
  | Some "search" -> text_input_role "searchbox" element
  | Some ("text" | "email" | "tel" | "url") -> text_input_role "textbox" element
  | None when absent "type_" element -> text_input_role "textbox" element
  | _ -> None

let intrinsic_roles =
  [
    ("article", "article");
    ("aside", "complementary");
    ("blockquote", "blockquote");
    ("button", "button");
    ("caption", "caption");
    ("code", "code");
    ("dd", "definition");
    ("del", "deletion");
    ("dfn", "term");
    ("dialog", "dialog");
    ("dt", "term");
    ("em", "emphasis");
    ("figure", "figure");
    ("hr", "separator");
    ("li", "listitem");
    ("main", "main");
    ("math", "math");
    ("menu", "list");
    ("meter", "meter");
    ("nav", "navigation");
    ("ol", "list");
    ("option", "option");
    ("p", "paragraph");
    ("progress", "progressbar");
    ("strong", "strong");
    ("sub", "subscript");
    ("sup", "superscript");
    ("table", "table");
    ("tbody", "rowgroup");
    ("td", "cell");
    ("textarea", "textbox");
    ("tfoot", "rowgroup");
    ("thead", "rowgroup");
    ("time", "time");
    ("tr", "row");
    ("ul", "list");
    ("h1", "heading");
    ("h2", "heading");
    ("h3", "heading");
    ("h4", "heading");
    ("h5", "heading");
    ("h6", "heading");
  ]

let named element =
  List.exists
    (fun name ->
      match string_prop name element with
      | Some value -> String.trim value <> ""
      | None -> false)
    [ "ariaLabel"; "ariaLabelledby"; "title" ]

let select_role element =
  if bool_prop "multiple" element = Some true then Some "listbox"
  else if
    not (absent "multiple" element || bool_prop "multiple" element = Some false)
  then None
  else
    match int_prop "size" element with
    | Some size -> Some (if size > 1 then "listbox" else "combobox")
    | None when absent "size" element -> Some "combobox"
    | _ -> None

let image_role element =
  if named element then Some "img"
  else
    match string_prop "alt" element with
    | Some "" ->
        let unnamed =
          List.for_all
            (fun name ->
              absent name element
              || Option.exists
                   (fun value -> String.trim value = "")
                   (string_prop name element))
            [ "ariaLabel"; "ariaLabelledby"; "title" ]
        in
        if unnamed then Some "presentation" else None
    | Some _ -> Some "img"
    | None -> if absent "alt" element then Some "img" else None

let implicit_role element =
  match intrinsic_tag element with
  | Some "input" -> input_role element
  | Some "select" -> select_role element
  | Some ("a" | "area") when present "href" element -> Some "link"
  | Some "img" -> image_role element
  | Some "section" when named element -> Some "region"
  | Some "form" when named element -> Some "form"
  | Some "th" -> (
      match string_prop "scope" element with
      | Some "row" | Some "rowgroup" -> Some "rowheader"
      | Some "col" | Some "colgroup" -> Some "columnheader"
      | _ -> None)
  | Some tag -> List.assoc_opt tag intrinsic_roles
  | None -> None

let native_interactive element =
  if element.spread then None
  else
    match intrinsic_tag element with
    | Some ("button" | "select" | "textarea" | "summary") -> Some true
    | Some "input" -> (
        match string_prop "type_" element with
        | Some "hidden" -> Some false
        | Some _ -> Some true
        | None -> if absent "type_" element then Some true else None)
    | Some ("a" | "area") -> (
        match prop "href" element with
        | Missing -> Some false
        | Value _ -> Some true
        | Unknown -> None)
    | Some ("audio" | "video") -> (
        match bool_prop "controls" element with
        | Some value -> Some value
        | None -> if absent "controls" element then Some false else None)
    | Some _ -> Some false
    | None -> None

let focusable element =
  if
    intrinsic_tag element = Some "input"
    && string_prop "type_" element = Some "hidden"
  then Some false
  else if
    bool_prop "hidden" element = Some true
    || bool_prop "disabled" element = Some true
  then Some false
  else if
    (not (absent "hidden" element || bool_prop "hidden" element = Some false))
    || not
         (absent "disabled" element || bool_prop "disabled" element = Some false)
  then None
  else
    match int_prop "tabIndex" element with
    | Some _ -> Some true
    | None when not (absent "tabIndex" element) -> None
    | None ->
        if bool_prop "contentEditable" element = Some true then Some true
        else if
          absent "contentEditable" element
          || bool_prop "contentEditable" element = Some false
        then native_interactive element
        else None

let aria_name name =
  if String.starts_with ~prefix:"aria-" name then Some name
  else if String.length name > 4 && String.starts_with ~prefix:"aria" name then
    Some
      ("aria-"
      ^ String.lowercase_ascii (String.sub name 4 (String.length name - 4)))
  else None

let native_tag role =
  List.assoc_opt role
    [
      ("button", "button");
      ("link", "a");
      ("checkbox", "input type_=\"checkbox\"");
      ("radio", "input type_=\"radio\"");
      ("textbox", "input");
      ("list", "ul");
      ("listitem", "li");
      ("navigation", "nav");
      ("main", "main");
      ("article", "article");
      ("table", "table");
      ("row", "tr");
      ("cell", "td");
      ("img", "img");
      ("heading", "h1 through h6");
      ("separator", "hr");
      ("progressbar", "progress");
    ]
