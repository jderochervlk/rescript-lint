module Lines = Set.Make (Int)
module Rules = Map.Make (String)

module Uses = Set.Make (struct
  type t = int * string

  let compare = compare
end)

type command = Line | Next_line | Disable | Enable

type directive = {
  command : command;
  rules : string list;
  reason : string option;
  range : Diagnostic.range;
}

type coverage = On_line of int | Region of int * int
type suppression = { directive : directive; rule : string; coverage : coverage }
type audit = Diagnostic.range * string
type regions = directive list Rules.t

type state = {
  regions : regions;
  suppressions : suppression list;
  audits : audit list;
}

let whitespace = function
  | ' ' | '\t' | '\r' | '\n' | '\012' -> true
  | _ -> false

let protected_rule rule =
  List.mem rule [ "syntax"; "suppression"; "analysis"; "read"; "write"; "fix" ]
  || String.ends_with ~suffix:"-analysis" rule

let comment_location comment =
  let location = Res_comment.loc comment in
  if Res_comment.is_single_line_comment comment then
    let start = location.loc_start in
    { location with loc_start = { start with pos_cnum = start.pos_cnum - 2 } }
  else location

let comment_range source comment =
  Source_range.of_location ~source (comment_location comment)

let words text =
  String.map
    (fun character -> if whitespace character then ' ' else character)
    text
  |> String.split_on_char ' '
  |> List.filter (fun word -> word <> "")

let rec reason_separator text offset =
  if offset + 1 >= String.length text then None
  else if
    text.[offset] = '-'
    && text.[offset + 1] = '-'
    && (offset = 0 || whitespace text.[offset - 1])
    && (offset + 2 = String.length text || whitespace text.[offset + 2])
  then Some offset
  else reason_separator text (offset + 1)

let split_reason text =
  match reason_separator text 0 with
  | None -> (text, None)
  | Some offset ->
      ( String.sub text 0 offset,
        Some
          (String.sub text (offset + 2) (String.length text - offset - 2)
          |> String.trim) )

let parse_command = function
  | "rescript-lint-disable-line" -> Some Line
  | "rescript-lint-disable-next-line" -> Some Next_line
  | "rescript-lint-disable" -> Some Disable
  | "rescript-lint-enable" -> Some Enable
  | _ -> None

let rule_list text =
  let parts = String.split_on_char ',' text |> List.map String.trim in
  if List.exists (fun part -> part = "") parts then
    Error "Name one or more exact rule IDs; empty comma entries are invalid."
  else
    let rules = List.concat_map words parts in
    if List.length (List.sort_uniq String.compare rules) <> List.length rules
    then Error "A directive must not repeat a rule ID."
    else Ok rules

let validate_rules known rules =
  let unknown =
    List.filter
      (fun rule -> (not (List.mem rule known)) || protected_rule rule)
      rules
  in
  match unknown with
  | [] -> Ok rules
  | _ ->
      Error
        ("Unknown or unsuppressible rule IDs: " ^ String.concat ", " unknown
       ^ ".")

let parse_directive known range text =
  let body, reason = split_reason text in
  match words body with
  | command :: _ -> (
      match parse_command command with
      | None -> Error "Malformed suppression directive: unsupported command."
      | Some command_kind ->
          let ids =
            String.sub body (String.length command)
              (String.length body - String.length command)
            |> String.trim
          in
          if reason = Some "" then
            Error "A reason separator must be followed by reason text."
          else
            Result.bind (rule_list ids) (fun rules ->
                Result.map
                  (fun rules ->
                    { command = command_kind; rules; reason; range })
                  (validate_rules known rules)))
  | [] -> Error "Malformed suppression directive."

let is_directive text =
  text = "rescript-lint"
  || String.starts_with ~prefix:"rescript-lint-" text
  || String.starts_with ~prefix:"rescript-lint " text

let parse_comments ~known_rules ~source comments =
  List.fold_left
    (fun (directives, audits) comment ->
      let text = String.trim (Res_comment.txt comment) in
      if
        Res_comment.is_doc_comment comment
        || Res_comment.is_module_comment comment
        || not (is_directive text)
      then (directives, audits)
      else
        let range = comment_range source comment in
        match parse_directive known_rules range text with
        | Ok directive -> (directive :: directives, audits)
        | Error message -> (directives, (range, message) :: audits))
    ([], []) comments

let documentation_ranges source tree =
  let ranges = ref [] in
  let visitor =
    {
      Ast_iterator.default_iterator with
      attribute =
        (fun _ ((name : string Location.loc), _) ->
          let range = Source_range.of_location ~source name.loc in
          let offset = range.start.byte_offset in
          if
            name.txt = "res.doc" && offset >= 0
            && offset + 3 <= String.length source
            && String.sub source offset 3 = "/**"
          then ranges := range :: !ranges);
    }
  in
  (match tree with
  | Parser.Implementation items -> visitor.structure visitor items
  | Interface items -> visitor.signature visitor items);
  !ranges

let syntax_lines source (document : Parser.document) =
  let ranges =
    List.map (comment_range source) document.comments
    @ documentation_ranges source document.tree
    |> List.sort (fun (left : Diagnostic.range) right ->
        Int.compare left.start.byte_offset right.start.byte_offset)
  in
  let rec scan offset line ranges lines =
    match ranges with
    | range :: rest when range.Diagnostic.finish.byte_offset <= offset ->
        scan offset line rest lines
    | range :: rest when range.start.byte_offset <= offset ->
        scan range.finish.byte_offset range.finish.line rest lines
    | _ when offset >= String.length source -> lines
    | _ when source.[offset] = '\n' -> scan (offset + 1) (line + 1) ranges lines
    | _ ->
        let lines =
          if whitespace source.[offset] then lines else Lines.add line lines
        in
        scan (offset + 1) line ranges lines
  in
  scan 0 1 ranges Lines.empty

let add_line lines state directive rule =
  let line =
    match directive.command with
    | Line -> directive.range.start.line
    | _ ->
        Option.value ~default:(-1)
          (Lines.find_first_opt
             (fun line -> line > directive.range.finish.line)
             lines)
  in
  {
    state with
    suppressions =
      { directive; rule; coverage = On_line line } :: state.suppressions;
  }

let disable state directive rule =
  let opened = Option.value ~default:[] (Rules.find_opt rule state.regions) in
  { state with regions = Rules.add rule (directive :: opened) state.regions }

let enable state directive rule =
  match Rules.find_opt rule state.regions with
  | Some (opening :: rest) ->
      let suppression =
        {
          directive = opening;
          rule;
          coverage =
            Region
              ( opening.range.start.byte_offset,
                directive.range.start.byte_offset );
        }
      in
      {
        state with
        regions = Rules.add rule rest state.regions;
        suppressions = suppression :: state.suppressions;
      }
  | _ ->
      {
        state with
        audits =
          (directive.range, "Unmatched enable directive for " ^ rule ^ ".")
          :: state.audits;
      }

let build lines audits directives =
  let step state directive =
    let apply =
      match directive.command with
      | Line | Next_line -> add_line lines
      | Disable -> disable
      | Enable -> enable
    in
    List.fold_left
      (fun state rule -> apply state directive rule)
      state directive.rules
  in
  List.fold_left step
    { regions = Rules.empty; suppressions = []; audits }
    directives

let finish_regions source_length state =
  Rules.fold
    (fun rule directives suppressions ->
      List.fold_left
        (fun suppressions directive ->
          {
            directive;
            rule;
            coverage =
              Region (directive.range.start.byte_offset, source_length + 1);
          }
          :: suppressions)
        suppressions directives)
    state.regions state.suppressions

let matches source (diagnostic : Diagnostic.t) suppression =
  source.Source.filename = diagnostic.filename
  && diagnostic.rule = suppression.rule
  &&
  match suppression.coverage with
  | On_line line -> diagnostic.range.start.line = line
  | Region (first, last) ->
      diagnostic.range.start.byte_offset >= first
      && diagnostic.range.start.byte_offset < last

let priority suppression =
  let kind = match suppression.coverage with On_line _ -> 1 | Region _ -> 0 in
  (kind, suppression.directive.range.start.byte_offset)

let suppress ~known_rules ~source suppressions diagnostics =
  let suppressions =
    List.sort
      (fun left right -> compare (priority right) (priority left))
      suppressions
  in
  List.fold_left
    (fun (remaining, used) (diagnostic : Diagnostic.t) ->
      let eligible =
        List.mem diagnostic.rule known_rules
        && not (protected_rule diagnostic.rule)
      in
      let suppression =
        if eligible then List.find_opt (matches source diagnostic) suppressions
        else None
      in
      match suppression with
      | None -> (diagnostic :: remaining, used)
      | Some suppression ->
          ( remaining,
            Uses.add
              (suppression.directive.range.start.byte_offset, suppression.rule)
              used ))
    ([], Uses.empty) diagnostics

let unused used suppression =
  if
    Uses.mem
      (suppression.directive.range.start.byte_offset, suppression.rule)
      used
  then None
  else
    let reason =
      Option.fold ~none:""
        ~some:(fun text -> " Reason: " ^ text)
        suppression.directive.reason
    in
    Some
      ( suppression.directive.range,
        "Unused suppression for " ^ suppression.rule ^ "." ^ reason )

let diagnostic (source : Source.t) (range, message) =
  Diagnostic.
    {
      filename = source.filename;
      rule = "suppression";
      range;
      message;
      fixes = [];
    }

let apply ~known_rules ~(source : Source.t) (document : Parser.document)
    diagnostics =
  let directives, audits =
    parse_comments ~known_rules ~source:source.text document.comments
  in
  let directives =
    List.sort
      (fun left right ->
        Int.compare left.range.start.byte_offset right.range.start.byte_offset)
      directives
  in
  let state = build (syntax_lines source.text document) audits directives in
  let suppressions = finish_regions (String.length source.text) state in
  let remaining, used =
    suppress ~known_rules ~source suppressions diagnostics
  in
  let audits =
    state.audits @ List.filter_map (unused used) suppressions
    |> List.map (diagnostic source)
  in
  Source_range.sort (List.rev remaining @ audits)
