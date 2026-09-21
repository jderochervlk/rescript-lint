open Rescript_linter

let source ?(kind = Source.Implementation) text =
  Source.{ filename = "jsx.res"; text; kind }

let check ?kind ?module_signatures name expected text =
  let source = source ?kind text in
  match Parser.parse source with
  | Error error -> Error (Lint_error.render error)
  | Ok tree ->
      let diagnostics =
        Jsx_rules.check ?module_signatures ~source tree
        |> List.filter (fun (item : Diagnostic.t) ->
            item.rule = "jsx-a11y/" ^ name)
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
    ("image alt missing", yes "alt-text" "<img src=\"photo.png\" />");
    ("decorative alt", no "alt-text" "<img alt=\"\" />");
    ("named image", no "alt-text" "<img ariaLabel=\"Profile\" />");
    ("area alternative", yes "alt-text" "<area href=\"/help\" />");
    ("image input alternative", yes "alt-text" "<input type_=\"image\" />");
    ( "object fallback",
      no "alt-text" "<object> {React.string(\"Document\")} </object>" );
    ("empty object", yes "alt-text" "<object />");
    ("ordinary input", no "alt-text" "<input type_=\"text\" />");
    ( "ambiguous link",
      yes "anchor-ambiguous-text"
        "<a href=\"/docs\"> {React.string(\"Click here!\")} </a>" );
    ( "descriptive link",
      no "anchor-ambiguous-text"
        "<a href=\"/docs\"> {React.string(\"Documentation\")} </a>" );
    ( "named ambiguous link",
      no "anchor-ambiguous-text"
        "<a href=\"/docs\" ariaLabel=\"Documentation\"> \
         {React.string(\"here\")} </a>" );
    ( "dynamic link text",
      no "anchor-ambiguous-text" "<a href=\"/docs\"> {label} </a>" );
    ( "nested link text",
      yes "anchor-ambiguous-text"
        "<a href=\"/docs\"> <span> {React.string(\"Read more\")} </span> </a>"
    );
    ( "shadowed React text",
      check "anchor-ambiguous-text" 0
        "module React = Other\n\
         let view = <a href=\"/docs\"> {React.string(\"here\")} </a>" );
    ( "open makes React ambiguous",
      check "anchor-ambiguous-text" 0
        "open Custom\n\
         let view = <a href=\"/docs\"> {React.string(\"here\")} </a>" );
    ("empty anchor", yes "anchor-has-content" "<a href=\"/docs\" />");
    ( "empty React string",
      yes "anchor-has-content" "<a href=\"/docs\"> {React.string(\" \" )} </a>"
    );
    ( "hidden link content",
      yes "anchor-has-content"
        "<a href=\"/docs\"> <span ariaHidden=true> {React.string(\"Docs\")} \
         </span> </a>" );
    ( "named anchor",
      no "anchor-has-content" "<a href=\"/docs\" ariaLabel=\"Docs\" />" );
    ( "image content",
      no "anchor-has-content" "<a href=\"/docs\"> <img alt=\"Docs\" /> </a>" );
    ( "hidden anchor",
      no "anchor-has-content" "<a href=\"/docs\" ariaHidden=true />" );
    ( "placeholder href",
      yes "anchor-is-valid" "<a href=\"#\"> {React.string(\"Docs\")} </a>" );
    ( "javascript href",
      yes "anchor-is-valid" "<a href=\"javascript:void(0)\" />" );
    ("action anchor", yes "anchor-is-valid" "<a onClick={_ => action()} />");
    ("fragment href", no "anchor-is-valid" "<a href=\"#details\" />");
    ("dynamic href", no "anchor-is-valid" "<a href={destination} />");
    ( "active descendant focus",
      yes "aria-activedescendant-has-tabindex"
        "<div ariaActivedescendant=\"selected\" />" );
    ( "active descendant tabindex",
      no "aria-activedescendant-has-tabindex"
        "<div ariaActivedescendant=\"selected\" tabIndex=0 />" );
    ( "native active descendant focus",
      no "aria-activedescendant-has-tabindex"
        "<input ariaActivedescendant=\"selected\" />" );
    ("invalid role", yes "aria-role" "<div role=\"clickable\" />");
    ("abstract role", yes "aria-role" "<div role=\"widget\" />");
    ("role fallback", no "aria-role" "<div role=\"future-role button\" />");
    ("dynamic role", no "aria-role" "<div role={role} />");
    ( "unsupported metadata",
      yes "aria-unsupported-elements" "<meta ariaHidden=true />" );
    ("ordinary aria", no "aria-unsupported-elements" "<div ariaHidden=true />");
    ( "invalid autocomplete",
      yes "autocomplete-valid" "<input autoComplete=\"electronic-mail\" />" );
    ( "valid autocomplete",
      no "autocomplete-valid" "<input autoComplete=\"email\" />" );
    ( "qualified autocomplete",
      no "autocomplete-valid"
        "<input autoComplete=\"section-account shipping home tel webauthn\" />"
    );
    ( "autocomplete off",
      no "autocomplete-valid" "<input autoComplete=\"off\" />" );
    ( "autocomplete contact mismatch",
      yes "autocomplete-valid" "<input autoComplete=\"home name\" />" );
    ( "autocomplete wrong order",
      yes "autocomplete-valid" "<input autoComplete=\"email shipping\" />" );
    ( "autocomplete invalid section",
      yes "autocomplete-valid" "<input autoComplete=\"section- name\" />" );
    ( "mouse click without keys",
      yes "click-events-have-key-events" "<div onClick={_ => action()} />" );
    ( "keyboard pair",
      no "click-events-have-key-events"
        "<div onClick={_ => action()} onKeyDown={_ => action()} />" );
    ( "native keyboard",
      no "click-events-have-key-events" "<button onClick={_ => action()} />" );
    ( "presentation click",
      no "click-events-have-key-events"
        "<div role=\"presentation\" onClick={_ => action()} />" );
    ( "control label missing",
      yes "control-has-associated-label" "<input type_=\"search\" />" );
    ( "explicit control label",
      no "control-has-associated-label" "<input ariaLabel=\"Search\" />" );
    ( "wrapped label",
      no "control-has-associated-label"
        "<label> {React.string(\"Search\")} <input /> </label>" );
    ( "linked label",
      no "control-has-associated-label"
        "<> <label htmlFor=\"search\"> {React.string(\"Search\")} </label> \
         <input id=\"search\" /> </>" );
    ( "hidden input",
      no "control-has-associated-label" "<input type_=\"hidden\" />" );
    ( "submit native label",
      no "control-has-associated-label" "<input type_=\"submit\" />" );
    ("empty heading", yes "heading-has-content" "<h2 />");
    ( "heading content",
      no "heading-has-content" "<h2> {React.string(\"Settings\")} </h2>" );
    ("missing document language", yes "html-has-lang" "<html />");
    ("document language", no "html-has-lang" "<html lang=\"en\" />");
    ("missing frame title", yes "iframe-has-title" "<iframe />");
    ("frame title", no "iframe-has-title" "<iframe title=\"Map\" />");
    ( "redundant image word",
      yes "img-redundant-alt" "<img alt=\"Image of a logo\" />" );
    ("descriptive alternative", no "img-redundant-alt" "<img alt=\"Acme\" />");
    ( "interactive role focus",
      yes "interactive-supports-focus"
        "<div role=\"button\" onClick={_ => action()} />" );
    ( "interactive role focused",
      no "interactive-supports-focus"
        "<div role=\"button\" tabIndex=0 onClick={_ => action()} />" );
    ( "unassociated label",
      yes "label-has-associated-control"
        "<label> {React.string(\"Name\")} </label>" );
    ( "nested control",
      no "label-has-associated-control" "<label> <input /> </label>" );
    ( "explicit association",
      no "label-has-associated-control"
        "<label htmlFor=\"name\"> {React.string(\"Name\")} </label>" );
    ("invalid language name", yes "lang" "<p lang=\"english\" />");
    ("language tag", no "lang" "<p lang=\"en-US\" />");
    ("script language tag", no "lang" "<p lang=\"zh-Hant-TW\" />");
    ("private language", no "lang" "<p lang=\"x-custom\" />");
    ("incomplete extension", yes "lang" "<p lang=\"en-u\" />");
    ("caption missing", yes "media-has-caption" "<video src=\"demo.mp4\" />");
    ( "audio caption missing",
      yes "media-has-caption" "<audio src=\"demo.mp3\" />" );
    ( "nonmedia does not need captions",
      no "media-has-caption" "<img alt=\"Profile\" />" );
    ( "sibling captions do not satisfy media",
      yes "media-has-caption" "<> <video /> <track kind=\"captions\" /> </>" );
    ( "nested captions remain recognized",
      no "media-has-caption"
        "<video> <div> <track kind=\"captions\" /> </div> </video>" );
    ( "nested control remains associated",
      no "label-has-associated-control"
        "<label> <span> <input /> </span> </label>" );
    ( "sibling control does not associate a label",
      yes "label-has-associated-control" "<> <label /> <input /> </>" );
    ( "nested hidden input does not associate a label",
      yes "label-has-associated-control"
        "<label> <input type_=\"hidden\" /> </label>" );
    ( "nonlabel is not checked for associated controls",
      no "label-has-associated-control" "<div> <input /> </div>" );
    ( "caption provided",
      no "media-has-caption"
        "<video> <track kind=\"captions\" src=\"demo.vtt\" /> </video>" );
    ("muted media", no "media-has-caption" "<video muted=true />");
    ("dynamic captions", no "media-has-caption" "<video> {tracks} </video>");
    ("custom captions", no "media-has-caption" "<video> <Captions /> </video>");
    ( "mouse focus missing",
      yes "mouse-events-have-key-events" "<div onMouseOver={_ => action()} />"
    );
    ( "mouse focus pair",
      no "mouse-events-have-key-events"
        "<div onMouseOver={_ => action()} onFocus={_ => action()} />" );
    ( "mouse leave missing blur",
      yes "mouse-events-have-key-events" "<div onMouseLeave={_ => action()} />"
    );
    ( "mouse blur pair",
      no "mouse-events-have-key-events"
        "<div onMouseOut={_ => action()} onBlur={_ => action()} />" );
    ("access key", yes "no-access-key" "<button accessKey=\"s\" />");
    ("no access key", no "no-access-key" "<button />");
    ( "hidden focusable",
      yes "no-aria-hidden-on-focusable" "<button ariaHidden=true />" );
    ( "hidden disabled",
      no "no-aria-hidden-on-focusable"
        "<button ariaHidden=true disabled=true />" );
    ( "hidden with negative tabindex",
      yes "no-aria-hidden-on-focusable" "<div ariaHidden=true tabIndex={-1} />"
    );
    ( "hidden nonfocusable",
      no "no-aria-hidden-on-focusable" "<span ariaHidden=true />" );
    ("autofocus", yes "no-autofocus" "<input autoFocus=true />");
    ("false autofocus", no "no-autofocus" "<input autoFocus=false />");
    ("distracting element", yes "no-distracting-elements" "<marquee />");
    ("ordinary element", no "no-distracting-elements" "<p />");
    ( "native interactive downgraded",
      yes "no-interactive-element-to-noninteractive-role"
        "<button role=\"presentation\" />" );
    ( "native interactive role",
      no "no-interactive-element-to-noninteractive-role"
        "<button role=\"button\" />" );
    ( "noninteractive handlers",
      yes "no-noninteractive-element-interactions"
        "<div onClick={_ => action()} />" );
    ( "interactive handlers",
      no "no-noninteractive-element-interactions"
        "<button onClick={_ => action()} />" );
    ( "noninteractive role upgraded",
      yes "no-noninteractive-element-to-interactive-role"
        "<li role=\"button\" />" );
    ( "permitted list role",
      no "no-noninteractive-element-to-interactive-role"
        "<li role=\"menuitem\" />" );
    ( "generic role",
      no "no-noninteractive-element-to-interactive-role"
        "<div role=\"button\" />" );
    ( "noninteractive tab stop",
      yes "no-noninteractive-tabindex" "<div tabIndex=0 />" );
    ("native tab stop", no "no-noninteractive-tabindex" "<button tabIndex=0 />");
    ( "negative tabindex",
      no "no-noninteractive-tabindex" "<div tabIndex={-1} />" );
    ("redundant role", yes "no-redundant-roles" "<button role=\"button\" />");
    ("nonredundant role", no "no-redundant-roles" "<div role=\"button\" />");
    ( "decorative equivalent role",
      yes "no-redundant-roles" "<img alt=\"\" role=\"none\" />" );
    ( "static interactions",
      yes "no-static-element-interactions" "<span onClick={_ => action()} />" );
    ( "role interactions",
      no "no-static-element-interactions"
        "<span role=\"button\" onClick={_ => action()} />" );
    ( "native tag preferred",
      yes "prefer-tag-over-role" "<div role=\"button\" />" );
    ("native tag used", no "prefer-tag-over-role" "<button role=\"button\" />");
    ( "required checked state",
      yes "role-has-required-aria-props" "<div role=\"checkbox\" />" );
    ( "checked state provided",
      no "role-has-required-aria-props"
        "<div role=\"checkbox\" ariaChecked=#\"true\" />" );
    ( "native checked semantics",
      no "role-has-required-aria-props"
        "<input type_=\"checkbox\" role=\"checkbox\" />" );
    ( "unsupported role state",
      yes "role-supports-aria-props"
        "<article role=\"article\" ariaChecked=#\"true\" />" );
    ( "supported role state",
      no "role-supports-aria-props"
        "<div role=\"checkbox\" ariaChecked=#\"true\" />" );
    ( "global role property",
      no "role-supports-aria-props"
        "<article role=\"article\" ariaLabel=\"Story\" />" );
    ( "prohibited generic name",
      yes "role-supports-aria-props"
        "<div role=\"generic\" ariaLabel=\"Story\" />" );
    ( "presentation globals",
      no "role-supports-aria-props"
        "<div role=\"presentation\" ariaHidden=true />" );
    ("invalid scope", yes "scope" "<td scope=\"col\" />");
    ("header scope", no "scope" "<th scope=\"col\" />");
    ("positive tabindex", yes "tabindex-no-positive" "<input tabIndex=2 />");
    ("zero tabindex", no "tabindex-no-positive" "<input tabIndex=0 />");
    ("dynamic tabindex", no "tabindex-no-positive" "<input tabIndex={index} />");
    ("spread alt unknown", no "alt-text" "<img {...props} />");
    ("optional alt unknown", no "alt-text" "<img alt=?alt />");
    ("custom component exempt", no "alt-text" "<Image />");
    ("custom element exempt", no "alt-text" "<custom-image />");
    ( "interface exempt",
      check ~kind:Source.Interface "alt-text" 0 "let image: Jsx.element" );
  ]

let semantic_checks =
  [
    ( "radio native role",
      yes "no-redundant-roles" "<input type_=\"radio\" role=\"radio\" />" );
    ( "slider native role",
      yes "no-redundant-roles" "<input type_=\"range\" role=\"slider\" />" );
    ( "spinbutton native role",
      yes "no-redundant-roles" "<input type_=\"number\" role=\"spinbutton\" />"
    );
    ( "text native role",
      yes "no-redundant-roles" "<input type_=\"text\" role=\"textbox\" />" );
    ( "list changes input role",
      yes "no-redundant-roles"
        "<input type_=\"email\" list=\"addresses\" role=\"combobox\" />" );
    ("select role", yes "no-redundant-roles" "<select role=\"combobox\" />");
    ( "multiple select role",
      yes "no-redundant-roles" "<select multiple=true role=\"listbox\" />" );
    ( "single select role",
      yes "no-redundant-roles" "<select multiple=false role=\"combobox\" />" );
    ( "large select role",
      yes "no-redundant-roles" "<select size=3 role=\"listbox\" />" );
    ( "small select role",
      yes "no-redundant-roles" "<select size=1 role=\"combobox\" />" );
    ( "dynamic select unknown",
      no "no-redundant-roles" "<select multiple={multi} role=\"combobox\" />" );
    ( "dynamic size unknown",
      no "no-redundant-roles" "<select size={size} role=\"combobox\" />" );
    ( "dynamic alt role unknown",
      no "no-redundant-roles" "<img alt={text} role=\"img\" />" );
    ( "image role",
      yes "no-redundant-roles" "<img alt=\"Profile\" role=\"img\" />" );
    ( "region named role",
      yes "no-redundant-roles"
        "<section ariaLabel=\"Content\" role=\"region\" />" );
    ( "form named role",
      yes "no-redundant-roles" "<form ariaLabel=\"Search\" role=\"form\" />" );
    ( "row header role",
      yes "no-redundant-roles" "<th scope=\"row\" role=\"rowheader\" />" );
    ( "column header role",
      yes "no-redundant-roles" "<th scope=\"col\" role=\"columnheader\" />" );
    ( "context dependent header",
      no "no-redundant-roles" "<th role=\"columnheader\" />" );
    ( "implicit unsupported state",
      yes "role-supports-aria-props" "<button ariaChecked=#\"true\" />" );
    ( "dynamic role tabindex unknown",
      no "no-noninteractive-tabindex" "<div role={role} tabIndex=0 />" );
    ( "empty associated label",
      yes "control-has-associated-label" "<label> <input /> </label>" );
    ( "custom child unknown content",
      no "anchor-has-content" "<a href=\"/docs\"> <Icon /> </a>" );
    ( "hidden focus owner",
      no "no-aria-hidden-on-focusable" "<button hidden=true ariaHidden=true />"
    );
    ( "unknown disabled focus",
      no "no-aria-hidden-on-focusable"
        "<button disabled={disabled} ariaHidden=true />" );
    ( "unknown tabindex focus",
      no "no-aria-hidden-on-focusable"
        "<div tabIndex={index} ariaHidden=true />" );
    ( "editable focus",
      yes "no-aria-hidden-on-focusable"
        "<div contentEditable=true ariaHidden=true />" );
    ( "unknown editable focus",
      no "no-aria-hidden-on-focusable"
        "<div contentEditable={editable} ariaHidden=true />" );
    ( "audio native focus",
      yes "no-aria-hidden-on-focusable"
        "<audio controls=true ariaHidden=true />" );
    ( "unknown audio focus",
      no "no-aria-hidden-on-focusable"
        "<audio controls={controls} ariaHidden=true />" );
    ( "input unknown type",
      no "no-aria-hidden-on-focusable" "<input type_={kind} ariaHidden=true />"
    );
    ( "unit children empty",
      yes "anchor-has-content" "<a href=\"/docs\"> {()} </a>" );
    ( "typed property",
      no "iframe-has-title" "<iframe title={(\"Map\": string)} />" );
    ( "dynamic track kind",
      no "media-has-caption" "<video> <track kind={kind} /> </video>" );
    ( "wrong track kind",
      yes "media-has-caption" "<video> <track kind=\"subtitles\" /> </video>" );
  ]

let precision_checks =
  [
    ( "implicit text input with list",
      yes "no-redundant-roles" "<input list=\"options\" role=\"combobox\" />" );
    ( "input with list is not plain textbox",
      no "no-redundant-roles" "<input list=\"options\" role=\"textbox\" />" );
    ( "input with optional list unknown",
      no "no-redundant-roles" "<input list=?options role=\"textbox\" />" );
    ( "search list role",
      yes "no-redundant-roles"
        "<input type_=\"search\" list=\"options\" role=\"combobox\" />" );
    ( "dynamic section name unknown",
      no "no-redundant-roles" "<section ariaLabel={label} role=\"region\" />" );
    ( "dynamic form name unknown",
      no "no-redundant-roles" "<form ariaLabel={label} role=\"form\" />" );
    ( "empty image alternative with name",
      yes "no-redundant-roles"
        "<img alt=\"\" ariaLabel=\"Profile\" role=\"img\" />" );
    ( "named image not presentational",
      no "no-redundant-roles"
        "<img alt=\"\" ariaLabel=\"Profile\" role=\"presentation\" />" );
    ( "dynamic image name unknown",
      no "no-redundant-roles"
        "<img alt=\"\" ariaLabel={label} role=\"presentation\" />" );
    ( "empty name retains decoration",
      yes "no-redundant-roles"
        "<img alt=\"\" title=\"\" role=\"presentation\" />" );
    ( "hidden ancestor excludes content audit",
      no "anchor-has-content"
        "<div ariaHidden=true> <a href=\"/docs\" /> </div>" );
    ( "unknown ancestor visibility",
      no "control-has-associated-label" "<div hidden={hidden}> <input /> </div>"
    );
    ( "unknown own visibility",
      no "heading-has-content" "<h2 ariaHidden={hidden} />" );
    ( "unknown click visibility",
      no "click-events-have-key-events"
        "<div ariaHidden={hidden} onClick={_ => action()} />" );
    ( "unknown presentation role",
      no "click-events-have-key-events"
        "<div role={role} onClick={_ => action()} />" );
    ( "fallback presentation role",
      no "click-events-have-key-events"
        "<div role=\"none button\" onClick={_ => action()} />" );
    ( "dynamic child label",
      no "anchor-has-content"
        "<a href=\"/docs\"> <span ariaLabel={label} /> </a>" );
    ( "dynamic image name",
      no "anchor-has-content" "<a href=\"/docs\"> <img alt={alt} /> </a>" );
    ( "hidden input tabindex does not focus",
      no "no-aria-hidden-on-focusable"
        "<input type_=\"hidden\" tabIndex=0 ariaHidden=true />" );
    ( "known Prelude preserves React",
      with_prelude "anchor-ambiguous-text" 1 "let value: int"
        "open Prelude\n\
         let view = <a href=\"/docs\"> {React.string(\"Click here\")} </a>" );
    ( "known conflicting Prelude shadows React",
      with_prelude "anchor-ambiguous-text" 0
        "module React: {let string: string => string}"
        "open Prelude\n\
         let view = <a href=\"/docs\"> {React.string(\"Click here\")} </a>" );
    ( "known nested Prelude",
      with_prelude "anchor-ambiguous-text" 1 "module Nested: {let value: int}"
        "open Prelude.Nested\n\
         let view = <a href=\"/docs\"> {React.string(\"Click here\")} </a>" );
    ( "unresolved nested Prelude",
      with_prelude "anchor-ambiguous-text" 0 "module Nested: Unknown"
        "open Prelude.Nested\n\
         let view = <a href=\"/docs\"> {React.string(\"Click here\")} </a>" );
    ( "known local open",
      with_prelude "anchor-ambiguous-text" 1 "let value: int"
        "let view = {open Prelude; <a href=\"/docs\"> {React.string(\"Click \
         here\")} </a>}" );
  ]

let () =
  let failures =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error detail -> Some (name ^ ": " ^ detail))
      (checks @ semantic_checks @ precision_checks
      @ List.map
          (fun role ->
            ( "concrete role " ^ role.Jsx_model.role_name,
              no "aria-role" ("<div role=\"" ^ role.role_name ^ "\" />") ))
          Jsx_model.roles)
  in
  List.iter prerr_endline failures;
  if List.length Jsx_rules.rule_ids <> 34 then (
    prerr_endline "Expected 34 accessibility rules";
    exit 1);
  match failures with [] -> () | _ -> exit 1
