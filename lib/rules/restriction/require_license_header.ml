let metadata =
  Rule_metadata.
    {
      id = "require-license-header";
      category = Restriction;
      enabled_by_default = false;
    }

open Project_rule_support

let license_comment license comment =
  Res_comment.txt comment |> String.split_on_char '\n'
  |> List.exists (fun line ->
      let line = String.trim line in
      let line =
        if String.starts_with ~prefix:"*" line then
          String.sub line 1 (String.length line - 1) |> String.trim
        else line
      in
      line = "SPDX-License-Identifier: " ^ license)

let first_item = function
  | Parser.Implementation (item :: _) ->
      item.Parsetree.pstr_loc.loc_start.pos_cnum
  | Interface (item :: _) -> item.Parsetree.psig_loc.loc_start.pos_cnum
  | _ -> max_int

let license_findings ~source options document =
  let first = first_item document.Parser.tree in
  let header =
    List.exists
      (fun comment ->
        (Res_comment.loc comment).loc_end.pos_cnum <= first
        && license_comment options.Project_options.license comment)
      document.comments
  in
  if header then []
  else
    [
      file_diagnostic source "require-license-header"
        ("Add a leading SPDX-License-Identifier: " ^ options.license
       ^ " comment.");
    ]
