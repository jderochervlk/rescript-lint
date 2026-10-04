let checks_react_semantic_rules_test_support =
  let open React_semantic_rules_test_support in
  [
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

let () = Rule_test_runner.run checks_react_semantic_rules_test_support
