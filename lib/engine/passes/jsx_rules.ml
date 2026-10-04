open Jsx_rule_support

let rule_ids =
  [
    Jsx_a11y_alt_text.metadata.id;
    Jsx_a11y_anchor_ambiguous_text.metadata.id;
    Jsx_a11y_anchor_has_content.metadata.id;
    Jsx_a11y_anchor_is_valid.metadata.id;
    Jsx_a11y_aria_activedescendant_has_tabindex.metadata.id;
    Jsx_a11y_aria_role.metadata.id;
    Jsx_a11y_aria_unsupported_elements.metadata.id;
    Jsx_a11y_autocomplete_valid.metadata.id;
    Jsx_a11y_click_events_have_key_events.metadata.id;
    Jsx_a11y_control_has_associated_label.metadata.id;
    Jsx_a11y_heading_has_content.metadata.id;
    Jsx_a11y_html_has_lang.metadata.id;
    Jsx_a11y_iframe_has_title.metadata.id;
    Jsx_a11y_img_redundant_alt.metadata.id;
    Jsx_a11y_interactive_supports_focus.metadata.id;
    Jsx_a11y_label_has_associated_control.metadata.id;
    Jsx_a11y_lang.metadata.id;
    Jsx_a11y_media_has_caption.metadata.id;
    Jsx_a11y_mouse_events_have_key_events.metadata.id;
    Jsx_a11y_no_access_key.metadata.id;
    Jsx_a11y_no_aria_hidden_on_focusable.metadata.id;
    Jsx_a11y_no_autofocus.metadata.id;
    Jsx_a11y_no_distracting_elements.metadata.id;
    Jsx_a11y_no_interactive_element_to_noninteractive_role.metadata.id;
    Jsx_a11y_no_noninteractive_element_interactions.metadata.id;
    Jsx_a11y_no_noninteractive_element_to_interactive_role.metadata.id;
    Jsx_a11y_no_noninteractive_tabindex.metadata.id;
    Jsx_a11y_no_redundant_roles.metadata.id;
    Jsx_a11y_no_static_element_interactions.metadata.id;
    Jsx_a11y_prefer_tag_over_role.metadata.id;
    Jsx_a11y_role_has_required_aria_props.metadata.id;
    Jsx_a11y_role_supports_aria_props.metadata.id;
    Jsx_a11y_scope.metadata.id;
    Jsx_a11y_tabindex_no_positive.metadata.id;
  ]

let inspect ~react_unshadowed elements tag element =
  let context = Jsx_rule_support.{ react_unshadowed; elements; tag; element } in
  Jsx_a11y_alt_text.inspect context
  @ Jsx_a11y_anchor_ambiguous_text.inspect context
  @ Jsx_a11y_anchor_has_content.inspect context
  @ Jsx_a11y_anchor_is_valid.inspect context
  @ Jsx_a11y_aria_activedescendant_has_tabindex.inspect context
  @ Jsx_a11y_aria_role.inspect context
  @ Jsx_a11y_aria_unsupported_elements.inspect context
  @ Jsx_a11y_autocomplete_valid.inspect context
  @ Jsx_a11y_click_events_have_key_events.inspect context
  @ Jsx_a11y_control_has_associated_label.inspect context
  @ Jsx_a11y_heading_has_content.inspect context
  @ Jsx_a11y_html_has_lang.inspect context
  @ Jsx_a11y_iframe_has_title.inspect context
  @ Jsx_a11y_img_redundant_alt.inspect context
  @ Jsx_a11y_interactive_supports_focus.inspect context
  @ Jsx_a11y_label_has_associated_control.inspect context
  @ Jsx_a11y_lang.inspect context
  @ Jsx_a11y_media_has_caption.inspect context
  @ Jsx_a11y_mouse_events_have_key_events.inspect context
  @ Jsx_a11y_no_access_key.inspect context
  @ Jsx_a11y_no_aria_hidden_on_focusable.inspect context
  @ Jsx_a11y_no_autofocus.inspect context
  @ Jsx_a11y_no_distracting_elements.inspect context
  @ Jsx_a11y_no_interactive_element_to_noninteractive_role.inspect context
  @ Jsx_a11y_no_noninteractive_element_interactions.inspect context
  @ Jsx_a11y_no_noninteractive_element_to_interactive_role.inspect context
  @ Jsx_a11y_no_noninteractive_tabindex.inspect context
  @ Jsx_a11y_no_redundant_roles.inspect context
  @ Jsx_a11y_no_static_element_interactions.inspect context
  @ Jsx_a11y_prefer_tag_over_role.inspect context
  @ Jsx_a11y_role_has_required_aria_props.inspect context
  @ Jsx_a11y_role_supports_aria_props.inspect context
  @ Jsx_a11y_scope.inspect context
  @ Jsx_a11y_tabindex_no_positive.inspect context

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
