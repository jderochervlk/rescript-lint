let aliased_module_dag () =
  let open Rescript_linter in
  let value =
    {
      (React_semantic_support.react_value [ "Helpers"; "eq" ]) with
      typ = Semantic_model.Function ([], Bool);
    }
  in
  let leaf = Semantic_model.add_value "eq" value Semantic_model.empty in
  let shared =
    List.fold_left
      (fun nested _ ->
        Semantic_model.empty
        |> Semantic_model.add_module "Left" nested
        |> Semantic_model.add_module "Right" nested)
      leaf (List.init 30 Fun.id)
  in
  let scope = Semantic_model.add_module "Helpers" shared Semantic_model.empty in
  let globals = React_semantic_support.globals scope in
  if
    React_semantic_support.Names.cardinal globals = 1
    && React_semantic_support.Names.mem value.identity globals
  then Ok ()
  else Error "aliased module DAG lost stable function identity"

let checks_react_semantic_rules_test_support =
  let open React_semantic_rules_test_support in
  [
    ( "changing external scalar alias",
      deps 1
        "@val external currentId: int = \"currentId\"\n\
         let useId = () => {let id = currentId\n\
         React.useMemo(() => id, [])}" );
    ( "changing external scalar alias chain",
      deps 1
        "@val external currentId: int = \"currentId\"\n\
         let useId = () => {let id = currentId\n\
         let alias = id\n\
         React.useMemo(() => alias, [])}" );
    ( "external module function alias",
      deps 0
        "module Helpers = {@module(\"./helpers.mjs\") external eq: (int, int) \
         => bool = \"eq\"}\n\
         let useEqual = (~left, ~right) => {let eq = Helpers.eq\n\
         React.useMemo(() => eq(left, right), (left, right))}" );
    ( "external alias chain and declaration shadowing",
      deps 0
        "module Helpers = {@module(\"./helpers.mjs\") external eq: (int, int) \
         => bool = \"eq\"}\n\
         let useEqual = (~left, ~right) => {let eq = Helpers.eq\n\
         let same = eq\n\
         module Helpers = {let eq = (a, b) => a == b}\n\
         let eq = left\n\
         React.useMemo(() => same(left, right), (left, right))}" );
    ( "nested module function higher order alias",
      deps 0
        "module Helpers = {module Nested = {let eq = (a, b) => a == b}}\n\
         let useEqual = (~left, ~right) => {module H = Helpers.Nested\n\
         let eq = H.eq\n\
         React.useMemo(() => Array.map(left, eq), (left, right))}" );
    ( "missing reactive input beside stable alias",
      deps 1
        "module Helpers = {let eq = (a, b) => a == b}\n\
         let useEqual = (~left, ~right) => {let eq = Helpers.eq\n\
         React.useMemo(() => eq(left, right), [left])}" );
    ( "parameter alias remains reactive",
      deps 1
        "let useEqual = (~eq, ~left, ~right) => {let same = eq\n\
         React.useMemo(() => same(left, right), (left, right))}" );
    ( "closure alias remains reactive",
      deps 1
        "let useEqual = (~left, ~right) => {let eq = (a, b) => a == left + b\n\
         let same = eq\n\
         React.useMemo(() => same(left, right), (left, right))}" );
    ( "local module closure remains reactive",
      deps 1
        "let useEqual = (~left, ~right) => {module Helpers = {let eq = (a, b) \
         => a == left + b}\n\
         let same = Helpers.eq\n\
         React.useMemo(() => same(left, right), (left, right))}" );
    ( "module function shadowed by parameter",
      deps 1
        "module Helpers = {let eq = (a, b) => a == b}\n\
         let useEqual = (~eq, ~left, ~right) => {let same = eq\n\
         React.useMemo(() => same(left, right), (left, right))}" );
    ( "record function alias remains reactive",
      deps 1
        "let useEqual = (~helpers, ~left, ~right) => {let eq = helpers.eq\n\
         React.useMemo(() => eq(left, right), (left, right))}" );
    ( "call result remains reactive",
      deps 1
        "module Helpers = {let create = () => (a, b) => a == b}\n\
         let useEqual = (~left, ~right) => {let eq = Helpers.create()\n\
         React.useMemo(() => eq(left, right), (left, right))}" );
    ( "unknown module member remains reactive",
      deps 1
        "let useEqual = (~left, ~right) => {let eq = UnknownHelpers.eq\n\
         React.useMemo(() => eq(left, right), (left, right))}" );
    ( "module callback stable",
      deps 0
        "let loadUser = _ => ()\n\
         let id = 1\n\
         React.useEffect1(() => {loadUser(id)\n\
         None}, [])" );
    ( "custom hook input reactive",
      deps 1
        "let loadUser = _ => ()\n\
         let useUser = id => React.useEffect1(() => {loadUser(id)\n\
         None}, [])" );
    ( "custom hook complete",
      deps 0
        "let loadUser = _ => ()\n\
         let useUser = id => React.useEffect1(() => {loadUser(id)\n\
         None}, [id])" );
    ( "missing param dependency",
      deps 1
        "@react.component let make = (~userId) => {React.useEffect1(() => \
         {loadUser(userId)\n\
         None}, [])\n\
         <div />}" );
    ( "provided param dependency",
      deps 0
        "@react.component let make = (~userId) => {React.useEffect1(() => \
         {loadUser(userId)\n\
         None}, [userId])\n\
         <div />}" );
    ( "field dependency",
      deps 0
        "@react.component let make = (~user) => {React.useEffect1(() => \
         {loadUser(user.id)\n\
         None}, [user.id])\n\
         <div />}" );
    ( "different field dependency",
      deps 1
        "@react.component let make = (~user) => {React.useEffect1(() => \
         {loadUser(user.name)\n\
         None}, [user.id])\n\
         <div />}" );
    ( "object dependency covers fields",
      deps 0
        "@react.component let make = (~user) => {React.useEffect1(() => \
         {loadUser(user.name)\n\
         None}, [user])\n\
         <div />}" );
    ( "callback local shadow",
      deps 0
        "@react.component let make = (~id) => {React.useEffect1(() => {let id \
         = 0\n\
         loadUser(id)\n\
         None}, [])\n\
         <div />}" );
    ( "global value stable",
      deps 0
        "let id = 1\n\
         @react.component let make = () => {React.useEffect1(() => {loadUser(id)\n\
         None}, [])\n\
         <div />}" );
    ( "tuple deps",
      deps 0
        "@react.component let make = (~left, ~right) => {React.useMemo2(() => \
         left + right, (left, right))\n\
         <div />}" );
    ( "zero dependency hook",
      deps 1
        "@react.component let make = (~id) => {React.useEffect0(() => \
         {loadUser(id)\n\
         None})\n\
         <div />}" );
    ( "hook alias",
      deps 1
        "let effect = React.useEffect1\n\
         @react.component let make = (~id) => {effect(() => {loadUser(id)\n\
         None}, [])\n\
         <div />}" );
    ( "module alias",
      deps 1
        "module R = React\n\
         @react.component let make = (~id) => {R.useEffect1(() => {loadUser(id)\n\
         None}, [])\n\
         <div />}" );
    ( "React shadow",
      deps 0
        "module React = {let useEffect1 = (callback, deps) => ()}\n\
         @react.component let make = (~id) => {React.useEffect1(() => \
         {loadUser(id)\n\
         None}, [])\n\
         <div />}" );
    ( "setter stable",
      deps 0
        "@react.component let make = () => {let (_, setCount) = \
         React.useState(() => 0)\n\
         React.useEffect1(() => {setCount(_ => 1)\n\
         None}, [])\n\
         <div />}" );
    ( "state reactive",
      deps 1
        "@react.component let make = () => {let (count, _) = React.useState(() \
         => 0)\n\
         React.useEffect1(() => {loadUser(count)\n\
         None}, [])\n\
         <div />}" );
    ( "callback binding",
      deps 1
        "@react.component let make = (~id) => {let effect = () => {loadUser(id)\n\
         None}\n\
         React.useEffect1(effect, [])\n\
         <div />}" );
    ( "annotation payload",
      deps 0 "@@example(React.useEffect1(() => {loadUser(id)\nNone}, []))" );
  ]

let () =
  Rule_test_runner.run checks_react_semantic_rules_test_support;
  Rule_test_runner.run [ ("aliased module DAG", aliased_module_dag ()) ]
