let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ("redundant role", yes "no-redundant-roles" "<button role=\"button\" />");
    ("nonredundant role", no "no-redundant-roles" "<div role=\"button\" />");
    ( "decorative equivalent role",
      yes "no-redundant-roles" "<img alt=\"\" role=\"none\" />" );
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
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
