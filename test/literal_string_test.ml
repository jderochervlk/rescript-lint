open Rescript_linter

let compare expected left right =
  match (Literal_string.decode left, Literal_string.decode right) with
  | Some left, Some right ->
      let actual = Literal_string.compare left right in
      Int.compare actual 0 = expected
      && Literal_string.equal left right = (expected = 0)
  | _ -> false

let equal = compare 0
let less = compare (-1)
let greater = compare 1
let unknown raw = Literal_string.decode raw = None

let checks =
  [
    ("empty", equal "" "");
    ("ASCII equal", equal "hello" "hello");
    ("ASCII different", less "a" "b");
    ("prefix", less "a" "aa");
    ("empty prefix", less "" "a");
    ("Unicode escape", equal {|\u0061|} "a");
    ("uppercase Unicode escape", equal {|\u00E9|} "\195\169");
    ("escaped slash", equal {|\/|} "/");
    ("escaped quote", equal {|\"|} "\"");
    ("escaped backslash", equal {|\\|} {|\u005c|});
    ("backspace", equal {|\b|} "\b");
    ("form feed", equal {|\f|} "\012");
    ("newline", equal {|\n|} "\n");
    ("carriage return", equal {|\r|} "\r");
    ("tab", equal {|\t|} "\t");
    ("equivalent escapes", equal {|\n|} {|\u000A|});
    ("null scalar", equal {|\u0000|} "\000");
    ("literal escaped escape", greater {|\\b|} {|\b|});
    ("escape followed by text", equal {|a\nb|} "a\nb");
    ("raw multiline", equal "a\nb" "a\nb");
    ("Unicode three bytes", equal "\226\130\172" {|\u20ac|});
    ("Unicode four bytes", equal "\240\159\152\128" {|\ud83d\ude00|});
    ("lowest surrogate pair", equal "\240\144\128\128" {|\ud800\udc00|});
    ("highest surrogate pair", equal "\244\143\191\191" {|\udbff\udfff|});
    ("UTF16 ordering", less "\240\144\128\128" "\238\128\128");
    ("UTF16 inverse ordering", greater "\238\128\128" "\240\144\128\128");
    ("no Unicode normalization", greater "\195\169" "e\204\129");
    ("BMP ordering", less "\195\169" "\226\130\172");
    ("invalid continuation", unknown "\128");
    ("truncated UTF8", unknown "\226\130");
    ("overlong UTF8", unknown "\192\128");
    ("raw high surrogate", unknown "\237\160\128");
    ("raw low surrogate", unknown "\237\176\128");
    ("out of range UTF8", unknown "\244\144\128\128");
    ("isolated high surrogate", unknown {|\ud800|});
    ("isolated low surrogate", unknown {|\udc00|});
    ("reversed surrogates", unknown {|\udc00\ud800|});
    ("high surrogate followed by ASCII", unknown {|\ud800\u0061|});
    ("invalid UTF8 after valid escape", unknown ("\\n" ^ "\128"));
    ("hex remains unknown", unknown {|\x61|});
    ("decimal remains unknown", unknown {|\097|});
    ("braced Unicode remains unknown", unknown {|\u{61}|});
    ("identity escape remains unknown", unknown {|\q|});
    ("vertical tab remains unknown", unknown {|\v|});
    ("short null remains unknown", unknown {|\0|});
    ("single quote escape remains unknown", unknown {|\'|});
    ("line continuation remains unknown", unknown "\\\n");
    ("unfinished escape", unknown "\\");
    ("short Unicode escape", unknown {|\u00|});
    ("invalid Unicode digit", unknown {|\uGGGG|});
    ("trailing comment is not part of a string", unknown {|\n" //|});
    ("trailing token is not part of a string", unknown {|\n" null|});
  ]

let () =
  let failures =
    List.filter_map (fun (name, ok) -> if ok then None else Some name) checks
  in
  List.iter prerr_endline failures;
  match failures with [] -> () | _ :: _ -> exit 1
