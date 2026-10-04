let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
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
    ( "hidden input tabindex does not focus",
      no "no-aria-hidden-on-focusable"
        "<input type_=\"hidden\" tabIndex=0 ariaHidden=true />" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
