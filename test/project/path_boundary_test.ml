open Rescript_linter

let checks =
  let contains platform root path =
    Path_boundary.contains ~platform ~root path
  in
  [
    ("empty root", not (contains Posix "" "/repo"));
    ("same root", contains Posix "/repo" "/repo");
    ("child", contains Posix "/repo" "/repo/src/Main.res");
    ("sibling prefix", not (contains Posix "/repo" "/repository/Main.res"));
    ("short path", not (contains Posix "/repo" "/"));
    ("filesystem root", contains Posix "/" "/src");
    ("trailing separator", contains Posix "/repo/" "/repo/src");
    ("posix case preserved", not (contains Posix "/Repo" "/repo/src"));
    ("posix backslash preserved", not (contains Posix "/repo" "/repo\\src"));
    ("windows child", contains Windows "C:\\repo" "C:\\repo\\src\\Main.res");
    ("windows same root", contains Windows "C:\\repo" "C:\\repo");
    ("windows mixed separators", contains Windows "C:/repo" "C:\\repo\\src");
    ("resolved case preserved", not (contains Windows "C:\\Repo" "C:/repo/src"));
    ("drive root", contains Windows "C:\\" "C:\\repo");
    ("different drive", not (contains Windows "C:\\repo" "D:\\repo\\src"));
    ("windows sibling", not (contains Windows "C:\\repo" "C:\\repository"));
    ("UNC root", contains Windows "\\\\server\\share\\" "\\\\server\\share\\src");
    ( "different UNC share",
      not (contains Windows "\\\\server\\share" "\\\\server\\other\\src") );
    ( "relative exclusion",
      contains Windows "src/generated" "src\\generated\\Main.res" );
  ]

let () =
  let failed =
    List.filter_map
      (fun (name, passed) -> if passed then None else Some name)
      checks
  in
  List.iter prerr_endline failed;
  if failed <> [] then exit 1
