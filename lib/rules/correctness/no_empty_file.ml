let metadata =
  Rule_metadata.
    { id = "no-empty-file"; category = Correctness; enabled_by_default = false }

let meaningful_item (item : Parsetree.structure_item) =
  match item.pstr_desc with Pstr_attribute _ -> false | _ -> true

let inspect_empty_file ~emit = function
  | Parser.Implementation items when not (List.exists meaningful_item items) ->
      let position =
        { Lexing.dummy_pos with pos_lnum = 1; pos_bol = 0; pos_cnum = 0 }
      in
      emit "no-empty-file" "This implementation file contains no declarations."
        { Location.loc_start = position; loc_end = position; loc_ghost = false }
  | _ -> ()
