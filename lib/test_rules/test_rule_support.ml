type context = {
  suite : int list;
  depth : int;
  test : int option;
  conditional : bool;
  calls : int list;
  active : bool;
}

type registration = {
  api : Test_scope.registration;
  title : (string * Location.t) option;
  flags : (string * Location.t) list;
  location : Location.t;
  key : int;
  context : context;
  callback_known : bool;
}

type event =
  | Registration of registration
  | Hook of Test_scope.hook * Location.t * context
  | Assertion of Location.t * Location.t * context
  | Disabled of Location.t

let hook_rank = function
  | Test_scope.Before_all -> 0
  | Before_each -> 1
  | After_each -> 2
  | After_all -> 3

let assertion_owner = function
  | Assertion (_, _, { test = Some key; _ }) -> Some key
  | _ -> None

let same_suite context = function
  | Registration value ->
      context.active && value.context.active
      && context.suite = value.context.suite
  | Hook (_, _, other) | Assertion (_, _, other) ->
      context.active && other.active && context.suite = other.suite
  | Disabled _ -> false
