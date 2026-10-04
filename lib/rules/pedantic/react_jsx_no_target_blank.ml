let metadata =
  Rule_metadata.
    {
      id = "react/jsx-no-target-blank";
      category = Pedantic;
      enabled_by_default = false;
    }

open React_dom_support

let external_target element =
  match M.prop "href" element with
  | M.Missing -> false
  | Unknown -> false
  | Value expression -> (
      match M.string expression with
      | None -> true
      | Some text ->
          String.starts_with ~prefix:"https://" text
          || String.starts_with ~prefix:"http://" text
          || String.starts_with ~prefix:"//" text)

let unsafe_relation element =
  match M.prop "rel" element with
  | M.Missing -> true
  | Unknown -> false
  | Value expression ->
      Option.exists
        (fun text ->
          let words = M.words (String.lowercase_ascii text) in
          not (List.mem "noopener" words || List.mem "noreferrer" words))
        (M.string expression)

let inspect tag element =
  issue "jsx-no-target-blank"
    (List.mem tag [ "a"; "area" ]
    && M.string_prop "target" element = Some "_blank"
    && external_target element && unsafe_relation element)
    "Protect this new browsing context with rel=\"noopener noreferrer\"."
