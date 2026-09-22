let newline text =
  match String.index_opt text '\n' with
  | Some index when index > 0 && text.[index - 1] = '\r' -> "\r\n"
  | _ -> "\n"

let comment_boundary previous next comments =
  let between comment =
    let loc = Res_comment.loc comment in
    loc.loc_start.Lexing.pos_bol >= previous.Lexing.pos_bol
    && loc.loc_start.pos_cnum >= previous.pos_cnum
    && loc.loc_end.pos_cnum <= next.Lexing.pos_cnum
  in
  let rec split ending = function
    | comment :: rest ->
        let loc = Res_comment.loc comment in
        if loc.loc_start.pos_lnum = ending.Lexing.pos_lnum then
          split loc.loc_end rest
        else (ending, loc.loc_start)
    | [] -> (ending, next)
  in
  split previous (List.filter between comments)

let opening_group_start text lower finish =
  (* Parentheses are absent from AST locations; keep them with the next row. *)
  let rec walk cursor first =
    if cursor <= lower then first
    else
      match text.[cursor - 1] with
      | '(' -> walk (cursor - 1) (cursor - 1)
      | ' ' | '\t' -> walk (cursor - 1) first
      | _ -> first
  in
  walk finish finish

let edit_for_gap ~(source : Source.t) previous next =
  let range = Source_range.of_positions ~source:source.text previous next in
  let start = range.start.byte_offset and finish = range.finish.byte_offset in
  if finish < start then None
  else
    let gap = String.sub source.text start (finish - start) in
    let lines =
      String.fold_left (fun n c -> if c = '\n' then n + 1 else n) 0 gap
    in
    if lines >= 2 then None
    else
      let at =
        if lines > 0 then next.Lexing.pos_bol
        else opening_group_start source.text start finish
      in
      let text =
        if lines > 0 then newline source.text
        else newline source.text ^ newline source.text
      in
      Some Text_edit.{ start = at; finish = at; text }

let boundary ~source ~comments left right =
  if
    (not (left.Layout_node.after || right.Layout_node.before))
    || left.loc.loc_ghost || right.loc.loc_ghost
  then None
  else
    let ending, start =
      comment_boundary left.loc.loc_end right.loc.loc_start comments
    in
    Option.map
      (fun edit ->
        let range =
          Source_range.of_positions ~source:source.Source.text start start
        in
        Diagnostic.
          {
            filename = source.filename;
            rule = "blank-lines";
            message =
              "Separate these declarations or statements with a blank line.";
            range;
            help = None;
            symbol = None;
            fixes = [ edit ];
          })
      (edit_for_gap ~source ending start)

let pairs emit nodes =
  let rec walk = function
    | left :: (right :: _ as rest) ->
        emit left right;
        walk rest
    | _ -> ()
  in
  walk nodes

let expression_boundaries emit (expr : Parsetree.expression) =
  match expr.pexp_desc with
  | Pexp_sequence (left, right) ->
      emit (Layout_node.expression left) (Layout_node.first right)
  | Pexp_let (_, bindings, body) ->
      emit (Layout_node.bindings bindings) (Layout_node.first body)
  | Pexp_letmodule (_, _, body)
  | Pexp_letexception (_, body)
  | Pexp_open (_, _, body) ->
      emit (Layout_node.first expr) (Layout_node.first body)
  | Pexp_jsx_element (Jsx_fragment { jsx_fragment_children = children; _ })
  | Pexp_jsx_element
      (Jsx_container_element { jsx_container_element_children = children; _ })
    ->
      pairs emit (List.map Layout_node.expression children)
  | _ -> ()

let iterator emit =
  let default = Ast_iterator.default_iterator in
  {
    default with
    structure =
      (fun self items ->
        pairs emit (List.map Layout_node.structure items);
        default.structure self items);
    signature =
      (fun self items ->
        pairs emit (List.map Layout_node.signature items);
        default.signature self items);
    expr =
      (fun self expr ->
        expression_boundaries emit expr;
        default.expr self expr);
    attributes = (fun _ _ -> ());
  }

let check ~source (document : Parser.document) =
  (* The compiler iterator is imperative; accumulation stays at this boundary. *)
  let diagnostics = ref [] in
  let emit left right =
    Option.iter
      (fun diagnostic -> diagnostics := diagnostic :: !diagnostics)
      (boundary ~source ~comments:document.comments left right)
  in
  let visitor = iterator emit in
  (match document.tree with
  | Implementation tree -> visitor.structure visitor tree
  | Interface tree -> visitor.signature visitor tree);
  List.sort_uniq
    (fun (left : Diagnostic.t) (right : Diagnostic.t) ->
      Int.compare left.range.start.byte_offset right.range.start.byte_offset)
    !diagnostics
