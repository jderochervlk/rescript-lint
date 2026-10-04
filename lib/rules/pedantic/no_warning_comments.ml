let metadata =
  Rule_metadata.
    {
      id = "no-warning-comments";
      category = Pedantic;
      enabled_by_default = false;
    }

open Policy_rule_support

let word_character = function
  | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' -> true
  | character -> Char.code character >= 128

let warning_terms policy text =
  let words =
    text |> String.uppercase_ascii
    |> String.map (fun character ->
        if word_character character then character else ' ')
    |> String.split_on_char ' '
  in
  List.filter (fun term -> List.mem term words) policy.terms

let inspect_warning ~emit policy context text location =
  let terms =
    if List.mem context policy.allowed_contexts then []
    else warning_terms policy text
  in
  match terms with
  | [] -> ()
  | terms ->
      emit "no-warning-comments"
        ("This comment contains a warning term: " ^ String.concat ", " terms
       ^ ".")
        location

let comment_context comment =
  if Res_comment.is_single_line_comment comment then Line
  else if
    Res_comment.is_doc_comment comment || Res_comment.is_module_comment comment
  then Documentation
  else Block

let inspect_comment ~emit policy comment =
  let location = Res_comment.loc comment in
  let location =
    if Res_comment.is_single_line_comment comment then
      let start = location.loc_start in
      { location with loc_start = { start with pos_cnum = start.pos_cnum - 2 } }
    else location
  in
  inspect_warning ~emit policy (comment_context comment)
    (Res_comment.txt comment) location

let documentation_source ~(source : Source.t) location =
  let range = Source_range.of_location ~source:source.text location in
  let start = range.start.byte_offset in
  start >= 0
  && start + 3 <= String.length source.text
  && String.sub source.text start 3 = "/**"

let inspect_attribute ~source ~emit policy = function
  | ( { Location.txt = "res.doc"; loc },
      Parsetree.PStr
        [
          {
            pstr_desc =
              Pstr_eval
                ({ pexp_desc = Pexp_constant (Pconst_string (text, _)); _ }, _);
            _;
          };
        ] )
    when documentation_source ~source loc ->
      inspect_warning ~emit policy Documentation text loc
  | _ -> ()

let inspect_documentation ~source ~emit policy tree =
  traverse
    {
      Ast_iterator.default_iterator with
      attribute =
        (fun _ attribute -> inspect_attribute ~source ~emit policy attribute);
    }
    tree
