type directory = { path : string; recursive : bool }

type t = {
  name : string;
  namespace : string option;
  dependencies : string list;
  directories : directory list;
}

val decode : Yojson.Basic.t -> (t, string) result
