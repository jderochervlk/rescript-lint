open Rescript_linter

let source ?(kind = Source.Implementation) text =
  Source.{ filename = "react-dom.res"; text; kind }

let check ?kind ?module_signatures name expected text =
  let source = source ?kind text in
  match Parser.parse source with
  | Error error -> Error (Lint_error.render error)
  | Ok tree ->
      let diagnostics =
        React_dom_rules.check ?module_signatures ~source tree
        |> List.filter (fun (item : Diagnostic.t) ->
            item.rule = "react/" ^ name)
      in
      if List.length diagnostics = expected then Ok ()
      else
        Error
          (Printf.sprintf "%s: expected %d, got %d for %s" name expected
             (List.length diagnostics) text)

let yes name text = check name 1 ("let view = " ^ text)
let no name text = check name 0 ("let view = " ^ text)

let with_prelude name expected signature text =
  match Parser.parse (source ~kind:Source.Interface signature) with
  | Ok (Parser.Interface items) ->
      check ~module_signatures:[ ("Prelude", items) ] name expected text
  | Ok _ -> Error "Expected interface"
  | Error error -> Error (Lint_error.render error)

let checks =
  [
    ("array item key", yes "jsx-key" "[<li />]");
    ("array item has key", no "jsx-key" "[<li key=\"a\" />]");
    ("fragment array key", yes "jsx-key" "[<> <li /> </>]");
    ("mapped item key", yes "jsx-key" "items->Array.map(item => <li />)");
    ("direct mapped item key", yes "jsx-key" "Array.map(items, item => <li />)");
    ("mapped component key", yes "jsx-key" "items->Array.map(item => <Item />)");
    ( "mapped key supplied",
      no "jsx-key" "items->Array.map(item => <Item key={item.id} />)" );
    ( "indexed mapped key supplied",
      no "jsx-key"
        "items->Array.mapWithIndex((item, index) => <Item key={item.id} />)" );
    ( "mapped branch keys",
      check "jsx-key" 2
        "let view = items->Array.map(item => if item.ready {<li />} else {<li \
         />})" );
    ( "mapped case key",
      yes "jsx-key"
        "items->Array.map(item => switch item {| Some(value) => <li /> | None \
         => React.null})" );
    ( "mapped local binding",
      yes "jsx-key" "items->Array.map(item => {let title = item.title; <li />})"
    );
    ( "mapped sequence",
      yes "jsx-key" "items->Array.map(item => {Console.log(item); <li />})" );
    ( "mapped nested static child",
      no "jsx-key" "items->Array.map(item => <li key={item.id}> <span /> </li>)"
    );
    ("ordinary child doesn't need key", no "jsx-key" "<ul> <li /> </ul>");
    ( "spread might supply key",
      no "jsx-key" "items->Array.map(item => <li {...item} />)" );
    ("optional key unknown", no "jsx-key" "[<li key=?key />]");
    ("unrelated map ignored", no "jsx-key" "items->Custom.map(item => <li />)");
    ( "shadowed Array ignored",
      check "jsx-key" 0
        "module Array = Custom\nlet view = items->Array.map(item => <li />)" );
    ( "local module Array ignored",
      check "jsx-key" 0
        "let view = {module Array = Custom; items->Array.map(item => <li />)}"
    );
    ( "local open ignored",
      check "jsx-key" 0
        "let view = {open Custom; items->Array.map(item => <li />)}" );
    ("Belt mapped item", yes "jsx-key" "items->Belt.Array.map(item => <li />)");
    ( "index converted key",
      yes "no-array-index-key"
        "items->Array.mapWithIndex((item, position) => <li \
         key={position->Int.toString} />)" );
    ( "index direct key",
      yes "no-array-index-key"
        "items->Array.mapWithIndex((item, position) => <li key={position} />)"
    );
    ( "index functional conversion",
      yes "no-array-index-key"
        "items->Array.mapWithIndex((item, position) => <li \
         key={Int.toString(position)} />)" );
    ( "stable item key",
      no "no-array-index-key"
        "items->Array.mapWithIndex((item, position) => <li key={item.id} />)" );
    ( "parameter name isn't evidence",
      no "no-array-index-key"
        "items->Array.map(index => <li key={index->Int.toString} />)" );
    ( "shadowed index binding",
      no "no-array-index-key"
        "items->Array.mapWithIndex((item, index) => {let index = item.id; <li \
         key={index} />})" );
    ( "shadowed index pattern",
      no "no-array-index-key"
        "items->Array.mapWithIndex((item, index) => switch item {| Some(index) \
         => <li key={index} /> | None => React.null})" );
    ( "static literal list index allowed",
      no "no-array-index-key"
        "[\"one\", \"two\"]->Array.mapWithIndex((item, index) => <li \
         key={index->Int.toString} />)" );
    ( "allocated literal items aren't static",
      yes "no-array-index-key"
        "[{id: \"a\"}]->Array.mapWithIndex((item, index) => <li \
         key={index->Int.toString} />)" );
    ( "nested function isn't renderer result",
      no "no-array-index-key"
        "items->Array.mapWithIndex((item, index) => () => <li \
         key={index->Int.toString} />)" );
    ( "shadowed Int conversion ignored",
      check "no-array-index-key" 0
        "module Int = Custom\n\
         let view = items->Array.mapWithIndex((item, index) => <li \
         key={index->Int.toString} />)" );
    ( "children prop",
      yes "no-children-prop" "<Panel children={React.string(\"Settings\")} />"
    );
    ( "children syntax",
      no "no-children-prop" "<Panel> {React.string(\"Settings\")} </Panel>" );
    ("punned children", yes "no-children-prop" "<Panel children />");
    ("optional children", no "no-children-prop" "<Panel children=?children />");
    ( "inner HTML conflict",
      yes "no-danger-with-children"
        "<div dangerouslySetInnerHTML={html}> {React.string(\"Fallback\")} \
         </div>" );
    ( "inner HTML alone",
      no "no-danger-with-children" "<div dangerouslySetInnerHTML={html} />" );
    ( "custom inner HTML semantics",
      no "no-danger-with-children"
        "<Panel dangerouslySetInnerHTML={html}> {React.string(\"Fallback\")} \
         </Panel>" );
    ( "void children",
      yes "void-dom-elements-no-children"
        "<img src=\"logo.png\"> {React.string(\"Logo\")} </img>" );
    ( "void children prop",
      yes "void-dom-elements-no-children" "<input children={child} />" );
    ( "void inner HTML",
      yes "void-dom-elements-no-children"
        "<br dangerouslySetInnerHTML={html} />" );
    ("void empty", no "void-dom-elements-no-children" "<img src=\"logo.png\" />");
    ( "ordinary children",
      no "void-dom-elements-no-children" "<div> {React.string(\"Text\")} </div>"
    );
    ("button type missing", yes "button-has-type" "<button />");
    ("button type explicit", no "button-has-type" "<button type_=\"button\" />");
    ( "button submit explicit",
      no "button-has-type" "<button type_=\"submit\" />" );
    ("button dynamic type", no "button-has-type" "<button type_={kind} />");
    ("button spread type unknown", no "button-has-type" "<button {...props} />");
    ("custom button", no "button-has-type" "<Button />");
    ( "blank external unsafe",
      yes "jsx-no-target-blank"
        "<a href=\"https://example.com\" target=\"_blank\" />" );
    ( "blank dynamic URL unsafe",
      yes "jsx-no-target-blank" "<a href={externalUrl} target=\"_blank\" />" );
    ( "blank protocol relative unsafe",
      yes "jsx-no-target-blank" "<a href=\"//example.com\" target=\"_blank\" />"
    );
    ( "blank noopener safe",
      no "jsx-no-target-blank"
        "<a href={externalUrl} target=\"_blank\" rel=\"noopener\" />" );
    ( "blank noreferrer safe",
      no "jsx-no-target-blank"
        "<a href={externalUrl} target=\"_blank\" rel=\"noreferrer\" />" );
    ( "blank unrelated rel unsafe",
      yes "jsx-no-target-blank"
        "<a href={externalUrl} target=\"_blank\" rel=\"nofollow\" />" );
    ( "blank dynamic rel unknown",
      no "jsx-no-target-blank"
        "<a href={externalUrl} target=\"_blank\" rel={relation} />" );
    ( "blank internal URL",
      no "jsx-no-target-blank" "<a href=\"/docs\" target=\"_blank\" />" );
    ( "regular target",
      no "jsx-no-target-blank" "<a href={externalUrl} target=\"_self\" />" );
    ("missing href", no "jsx-no-target-blank" "<a target=\"_blank\" />");
    ( "iframe sandbox missing",
      yes "iframe-missing-sandbox" "<iframe src=\"/embed\" />" );
    ( "iframe sandbox provided",
      no "iframe-missing-sandbox" "<iframe sandbox=\"\" />" );
    ( "iframe dynamic sandbox",
      no "iframe-missing-sandbox" "<iframe sandbox={policy} />" );
    ( "iframe optional sandbox",
      no "iframe-missing-sandbox" "<iframe sandbox=?policy />" );
    ("custom iframe exempt", no "iframe-missing-sandbox" "<Frames.iframe />");
    ( "interface",
      check ~kind:Source.Interface "jsx-key" 0 "let view: Jsx.element" );
  ]

let precision_checks =
  [
    ( "Belt index is first argument",
      yes "no-array-index-key"
        "items->Belt.Array.mapWithIndex((position, item) => <li \
         key={position->Int.toString} />)" );
    ( "Belt item is second argument",
      no "no-array-index-key"
        "items->Belt.Array.mapWithIndex((position, item) => <li \
         key={item->Int.toString} />)" );
    ("List rendered items", yes "jsx-key" "items->List.map(item => <li />)");
    ( "List index is second argument",
      yes "no-array-index-key"
        "items->List.mapWithIndex((item, position) => <li \
         key={position->Int.toString} />)" );
    ( "Belt List index is first argument",
      yes "no-array-index-key"
        "items->Belt.List.mapWithIndex((position, item) => <li \
         key={position->Int.toString} />)" );
    ( "typed callback index",
      yes "no-array-index-key"
        "items->Array.mapWithIndex((item, position: int) => <li \
         key={position->Int.toString} />)" );
    ( "known Prelude preserves Array",
      with_prelude "jsx-key" 1 "let items: array<int>"
        "open Prelude\nlet view = items->Array.map(item => <li />)" );
    ( "known Prelude preserves indexed Array",
      with_prelude "no-array-index-key" 1 "let items: array<int>"
        "open Prelude\n\
         let view = items->Array.mapWithIndex((item, index) => <li \
         key={index->Int.toString} />)" );
    ( "known conflicting Prelude shadows Array",
      with_prelude "jsx-key" 0 "module Array: {let value: int}"
        "open Prelude\nlet view = items->Array.map(item => <li />)" );
    ( "project Array shadows runtime",
      check
        ~module_signatures:[ ("Array", []) ]
        "jsx-key" 0 "let view = items->Array.map(item => <li />)" );
    ( "functor Array shadows runtime",
      check "jsx-key" 0
        "module Make = (Array: {}) => {let view = items->Array.map(item => <li \
         />)}" );
  ]

let () =
  let failures =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
      (checks @ precision_checks)
  in
  List.iter prerr_endline failures;
  if List.length React_dom_rules.rule_ids <> 8 then (
    prerr_endline "Expected eight React DOM rules";
    exit 1);
  match failures with [] -> () | _ -> exit 1
