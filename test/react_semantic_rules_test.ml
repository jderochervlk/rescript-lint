open Rescript_linter

let check rule expected text =
  let source = Source.{ filename = "react.res"; kind = Implementation; text } in
  match Parser.parse source with
  | Error error -> Error (Lint_error.render error)
  | Ok tree ->
      let findings =
        React_semantic_rules.check ~source tree
        |> List.filter (fun (finding : Diagnostic.t) -> finding.rule = rule)
      in
      if List.length findings = expected then Ok ()
      else
        Error
          (Printf.sprintf "%s expected %d got %d: %s" rule expected
             (List.length findings) text)

let nested = check "react/no-unstable-nested-components"
let props = check "react/no-new-prop-value"
let context = check "react/jsx-no-constructed-context-values"
let deps = check "react/exhaustive-deps"

let checks =
  [
    ( "memo render props",
      props 1
        "@react.component let make = React.memo(() => <Item items={[1]} />)" );
    ( "memo comparator not render",
      props 1
        "@react.component let make = React.memo(() => <Item items={[1]} />, \
         (_, _) => {ignore(<Item items={[1]} />)\n\
         true})" );
    ( "forwardRef render props",
      props 1
        "@react.component let make = React.forwardRef((_, _) => <Item \
         items={[1]} />)" );
    ( "unresolved wrapper not render",
      props 0
        "@react.component let make = Other.wrap(() => <Item items={[1]} />)" );
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
    ( "nested module component",
      nested 1
        "@react.component let make = () => {module Row = {@react.component let \
         make = () => <span />}\n\
         <Row />}" );
    ( "module component stable",
      nested 0
        "module Row = {@react.component let make = () => <span />}\n\
         @react.component let make = () => <Row />" );
    ( "local ordinary function",
      nested 0
        "@react.component let make = () => {let helper = () => ()\n<div />}" );
    ( "array prop",
      props 1 "@react.component let make = () => <Item items={[1, 2]} />" );
    ( "function prop",
      props 1
        "@react.component let make = () => <Item onSelect={item => \
         choose(item)} />" );
    ( "record prop",
      props 1
        "@react.component let make = () => <Item data={{name: \"hello\"}} />" );
    ( "tuple prop",
      props 1 "@react.component let make = () => <Item data={(1, 2)} />" );
    ( "stable prop",
      props 0
        "let items = [1]\n@react.component let make = () => <Item items />" );
    ("outside render", props 0 "let item = <Item items={[1]} />");
    ( "literal prop",
      props 0 "@react.component let make = () => <Item value=1 />" );
    ( "nested callback not render",
      props 0
        "@react.component let make = () => {let handler = () => <Item \
         items={[1]} />\n\
         <div />}" );
    ( "context allocation",
      context 1
        "module Theme = {let context = React.createContext(0)\n\
         let make = React.Context.provider(context)}\n\
         @react.component let make = (~children) => <Theme value={{color: \
         \"blue\"}}> children </Theme>" );
    ( "ordinary value prop",
      context 0
        "@react.component let make = () => <Theme value={{color: \"blue\"}} />"
    );
    ( "stable context",
      context 0
        "module Theme = {let context = React.createContext(0)\n\
         let make = React.Context.provider(context)}\n\
         let theme = {color: \"blue\"}\n\
         @react.component let make = () => <Theme value=theme />" );
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
  let failed =
    List.filter_map
      (fun (name, result) ->
        match result with
        | Ok () -> None
        | Error message -> Some (name ^ ": " ^ message))
      checks
  in
  List.iter prerr_endline failed;
  if failed <> [] then exit 1
