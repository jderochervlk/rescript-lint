open Rescript_linter

let expected_categories =
  [
    ("no-console", Rule_metadata.Restriction);
    ("no-object-magic", Rule_metadata.Correctness);
    ("no-unsafe", Rule_metadata.Correctness);
    ("react/rules-of-hooks", Rule_metadata.Pedantic);
    ("no-unhandled-throws", Rule_metadata.Correctness);
    ("blank-lines", Rule_metadata.Style);
    ("no-constant-condition", Rule_metadata.Correctness);
    ("no-constant-binary-expression", Rule_metadata.Correctness);
    ("no-duplicate-condition", Rule_metadata.Correctness);
    ("no-identical-branches", Rule_metadata.Suspicious);
    ("no-debugger", Rule_metadata.Correctness);
    ("no-useless-catch", Rule_metadata.Correctness);
    ("no-catch-all-exception", Rule_metadata.Restriction);
    ("simplify-boolean-expression", Rule_metadata.Style);
    ("no-useless-concat", Rule_metadata.Suspicious);
    ("approx-constant", Rule_metadata.Suspicious);
    ("no-empty-function", Rule_metadata.Restriction);
    ("no-empty-file", Rule_metadata.Correctness);
    ("no-warning-comments", Rule_metadata.Pedantic);
    ("max-nesting", Rule_metadata.Pedantic);
    ("max-params", Rule_metadata.Style);
    ("max-lines-per-function", Rule_metadata.Pedantic);
    ("no-self-compare", Rule_metadata.Pedantic);
    ("no-unintended-shallow-equality", Rule_metadata.Suspicious);
    ("no-expensive-deep-equality", Rule_metadata.Perf);
    ("no-float-equality", Rule_metadata.Pedantic);
    ("prefer-pattern-check", Rule_metadata.Perf);
    ("prefer-empty-check", Rule_metadata.Perf);
    ("no-partial-function", Rule_metadata.Correctness);
    ("no-dynamic-code", Rule_metadata.Restriction);
    ("no-shared-array-initializer", Rule_metadata.Suspicious);
    ("no-floating-promise", Rule_metadata.Correctness);
    ("require-await", Rule_metadata.Pedantic);
    ("no-await-in-loop", Rule_metadata.Perf);
    ("only-used-in-recursion", Rule_metadata.Correctness);
    ("eta-reduction", Rule_metadata.Style);
    ("no-ignored-result", Rule_metadata.Correctness);
    ("fuse-collection-pipeline", Rule_metadata.Perf);
    ("no-accumulating-concat", Rule_metadata.Perf);
    ("no-top-level-side-effect", Rule_metadata.Restriction);
    ("no-redundant-mutual-recursion", Rule_metadata.Style);
    ("prefer-standard-combinator", Rule_metadata.Style);
    ("jsx-a11y/alt-text", Rule_metadata.Correctness);
    ("jsx-a11y/anchor-ambiguous-text", Rule_metadata.Restriction);
    ("jsx-a11y/anchor-has-content", Rule_metadata.Correctness);
    ("jsx-a11y/anchor-is-valid", Rule_metadata.Correctness);
    ("jsx-a11y/aria-activedescendant-has-tabindex", Rule_metadata.Correctness);
    ("jsx-a11y/aria-role", Rule_metadata.Correctness);
    ("jsx-a11y/aria-unsupported-elements", Rule_metadata.Correctness);
    ("jsx-a11y/autocomplete-valid", Rule_metadata.Correctness);
    ("jsx-a11y/click-events-have-key-events", Rule_metadata.Correctness);
    ("jsx-a11y/control-has-associated-label", Rule_metadata.Correctness);
    ("jsx-a11y/heading-has-content", Rule_metadata.Correctness);
    ("jsx-a11y/html-has-lang", Rule_metadata.Correctness);
    ("jsx-a11y/iframe-has-title", Rule_metadata.Correctness);
    ("jsx-a11y/img-redundant-alt", Rule_metadata.Correctness);
    ("jsx-a11y/interactive-supports-focus", Rule_metadata.Correctness);
    ("jsx-a11y/label-has-associated-control", Rule_metadata.Correctness);
    ("jsx-a11y/lang", Rule_metadata.Correctness);
    ("jsx-a11y/media-has-caption", Rule_metadata.Correctness);
    ("jsx-a11y/mouse-events-have-key-events", Rule_metadata.Correctness);
    ("jsx-a11y/no-access-key", Rule_metadata.Correctness);
    ("jsx-a11y/no-aria-hidden-on-focusable", Rule_metadata.Correctness);
    ("jsx-a11y/no-autofocus", Rule_metadata.Correctness);
    ("jsx-a11y/no-distracting-elements", Rule_metadata.Correctness);
    ( "jsx-a11y/no-interactive-element-to-noninteractive-role",
      Rule_metadata.Correctness );
    ( "jsx-a11y/no-noninteractive-element-interactions",
      Rule_metadata.Correctness );
    ( "jsx-a11y/no-noninteractive-element-to-interactive-role",
      Rule_metadata.Correctness );
    ("jsx-a11y/no-noninteractive-tabindex", Rule_metadata.Correctness);
    ("jsx-a11y/no-redundant-roles", Rule_metadata.Correctness);
    ("jsx-a11y/no-static-element-interactions", Rule_metadata.Correctness);
    ("jsx-a11y/prefer-tag-over-role", Rule_metadata.Correctness);
    ("jsx-a11y/role-has-required-aria-props", Rule_metadata.Correctness);
    ("jsx-a11y/role-supports-aria-props", Rule_metadata.Correctness);
    ("jsx-a11y/scope", Rule_metadata.Correctness);
    ("jsx-a11y/tabindex-no-positive", Rule_metadata.Correctness);
    ("react/jsx-key", Rule_metadata.Correctness);
    ("react/no-array-index-key", Rule_metadata.Perf);
    ("react/no-children-prop", Rule_metadata.Correctness);
    ("react/no-danger-with-children", Rule_metadata.Correctness);
    ("react/void-dom-elements-no-children", Rule_metadata.Correctness);
    ("react/button-has-type", Rule_metadata.Restriction);
    ("react/jsx-no-target-blank", Rule_metadata.Pedantic);
    ("react/iframe-missing-sandbox", Rule_metadata.Suspicious);
    ("no-obj-external", Rule_metadata.Restriction);
    ("no-mutable-record-field", Rule_metadata.Restriction);
    ("no-record-mutation", Rule_metadata.Restriction);
    ("no-while", Rule_metadata.Restriction);
    ("no-for", Rule_metadata.Restriction);
    ("no-empty-loop", Rule_metadata.Suspicious);
    ("no-negated-condition", Rule_metadata.Pedantic);
    ("no-nested-ternary", Rule_metadata.Style);
    ("prefer-if", Rule_metadata.Style);
    ("no-single-case-switch", Rule_metadata.Style);
    ("no-unnecessary-template", Rule_metadata.Style);
    ("max-lines", Rule_metadata.Pedantic);
    ("max-switch-cases", Rule_metadata.Pedantic);
    ("no-optional-some", Rule_metadata.Style);
    ("preferred-type-syntax", Rule_metadata.Style);
    ("no-identity-operation", Rule_metadata.Correctness);
    ("no-erasing-operation", Rule_metadata.Correctness);
    ("no-modulo-one", Rule_metadata.Correctness);
    ("react/no-unstable-nested-components", Rule_metadata.Suspicious);
    ("react/jsx-no-constructed-context-values", Rule_metadata.Perf);
    ("react/exhaustive-deps", Rule_metadata.Correctness);
    ("react/no-new-prop-value", Rule_metadata.Perf);
    ("test/no-focused-tests", Rule_metadata.Correctness);
    ("test/no-disabled-tests", Rule_metadata.Correctness);
    ("test/no-identical-title", Rule_metadata.Style);
    ("test/no-duplicate-hooks", Rule_metadata.Style);
    ("test/no-conditional-test", Rule_metadata.Correctness);
    ("test/no-conditional-expect", Rule_metadata.Correctness);
    ("test/prefer-hooks-in-order", Rule_metadata.Style);
    ("test/prefer-hooks-on-top", Rule_metadata.Style);
    ("test/require-top-level-describe", Rule_metadata.Style);
    ("test/valid-title", Rule_metadata.Correctness);
    ("test/expect-expect", Rule_metadata.Correctness);
    ("test/max-nested-describe", Rule_metadata.Style);
    ("no-restricted-modules", Rule_metadata.Restriction);
    ("forbidden-source-root-reference", Rule_metadata.Restriction);
    ("no-unused-export", Rule_metadata.Correctness);
    ("no-deprecated-api", Rule_metadata.Pedantic);
    ("require-interface", Rule_metadata.Restriction);
    ("require-license-header", Rule_metadata.Restriction);
  ]

let () =
  Rule_test_runner.run
    [
      ( "category assignments",
        if
          List.map
            (fun (rule : Rule_metadata.t) -> (rule.id, rule.category))
            Rule_catalog.rules
          = expected_categories
        then Ok ()
        else Error "category catalog drift" );
      ( "category names",
        if
          List.map Rule_metadata.category_name
            [ Correctness; Suspicious; Pedantic; Perf; Style; Restriction ]
          = [
              "correctness";
              "suspicious";
              "pedantic";
              "perf";
              "style";
              "restriction";
            ]
        then Ok ()
        else Error "category names" );
      ( "configuration uses the catalog",
        if Rule_config.rules = Rule_catalog.rules then Ok ()
        else Error "configuration catalog drift" );
    ]
