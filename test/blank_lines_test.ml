open Rescript_linter

let source kind text = Source.{ filename = "spacing.res"; kind; text }

let check kind input expected =
  let original = source kind input in
  Result.bind (Fixer.fix_source original) (fun (fixed, diagnostics) ->
      if fixed.text <> expected then
        Error
          (Lint_error.Fix_error
             {
               filename = "test";
               detail = Printf.sprintf "Expected %S, got %S" expected fixed.text;
             })
      else if
        List.exists
          (fun (d : Diagnostic.t) -> d.rule = "blank-lines")
          diagnostics
      then
        Error
          (Lint_error.Fix_error
             { filename = "test"; detail = "Still has spacing errors" })
      else
        Result.bind (Fixer.fix_source fixed) (fun (again, _) ->
            if again <> fixed then
              Error
                (Lint_error.Fix_error
                   { filename = "test"; detail = "Not idempotent" })
            else
              Result.bind (Parser.format fixed) (fun text ->
                  Result.bind
                    (Parser.parse_document { fixed with text })
                    (fun document ->
                      if
                        Blank_lines.check ~source:{ fixed with text } document
                        = []
                      then Ok ()
                      else
                        Error
                          (Lint_error.Fix_error
                             {
                               filename = "test";
                               detail = "Formatter removed separator";
                             })))))

let cases =
  [
    ( "external",
      Source.Implementation,
      "@val external read: unit => int = \"read\"\nlet value = read()\n",
      "@val external read: unit => int = \"read\"\n\nlet value = read()\n" );
    ( "annotations",
      Implementation,
      "let value = 1\n@react.component\nlet make = () => value\n",
      "let value = 1\n\n@react.component\nlet make = () => value\n" );
    ( "pipes",
      Implementation,
      "let value = input->convert->finish\nconsume(value)\n",
      "let value = input->convert->finish\n\nconsume(value)\n" );
    ( "switch value",
      Implementation,
      "let a = 1\nlet b = switch a {| 1 => 2 | _ => 0}\nconsume(b)\n",
      "let a = 1\n\nlet b = switch a {| 1 => 2 | _ => 0}\n\nconsume(b)\n" );
    ( "block",
      Implementation,
      "let f = () => {\n\
      \  let a = 1\n\
      \  switch a {| _ => consume(a)}\n\
      \  done()\n\
       }\n",
      "let f = () => {\n\
      \  let a = 1\n\n\
      \  switch a {| _ => consume(a)}\n\n\
      \  done()\n\
       }\n" );
    ( "comments",
      Implementation,
      "input->consume // trailing\n\
       // binding docs\n\
       @deprecated(\"old\")\n\
       let value = 1\n",
      "input->consume // trailing\n\n\
       // binding docs\n\
       @deprecated(\"old\")\n\
       let value = 1\n" );
    ( "interface",
      Interface,
      "@get external name: t => string = \"name\"\n\
       @send external save: t => unit = \"save\"\n\
       let value: int\n",
      "@get external name: t => string = \"name\"\n\n\
       @send external save: t => unit = \"save\"\n\n\
       let value: int\n" );
    ( "no boundary padding",
      Implementation,
      "let f = () => {\n  switch value {| _ => value->convert}\n}\n",
      "let f = () => {\n  switch value {| _ => value->convert}\n}\n" );
    ( "CRLF and no final newline",
      Implementation,
      "let value = input->convert\r\nconsume(value)",
      "let value = input->convert\r\n\r\nconsume(value)" );
    ( "multiline pipe",
      Implementation,
      "let value = input\n  ->convert\n  ->finish\nconsume(value)\n",
      "let value = input\n  ->convert\n  ->finish\n\nconsume(value)\n" );
    ( "typed pipe",
      Implementation,
      "let value = (input->convert: int)\nconsume(value)\n",
      "let value = (input->convert: int)\n\nconsume(value)\n" );
    ( "nested module and stacked annotations",
      Implementation,
      "module Api = {\n\
       let n = 0\n\
       @module(\"api\")\n\
       @scope(\"nested\")\n\
       external read: unit => int = \"read\"\n\
       let value = read()\n\
       }\n",
      "module Api = {\n\
       let n = 0\n\n\
       @module(\"api\")\n\
       @scope(\"nested\")\n\
       external read: unit => int = \"read\"\n\n\
       let value = read()\n\
       }\n" );
    ( "local annotation",
      Implementation,
      "let f = () => {\nlet a = 1\n@deprecated(\"old\")\nlet b = a\nb\n}\n",
      "let f = () => {\nlet a = 1\n\n@deprecated(\"old\")\nlet b = a\nb\n}\n" );
    ( "local module before switch",
      Implementation,
      "let f = () => {\nmodule M = {}\nswitch v {| _ => v}\n}\n",
      "let f = () => {\nmodule M = {}\n\nswitch v {| _ => v}\n}\n" );
    ( "local open before switch",
      Implementation,
      "let f = () => {\nopen M\nswitch v {| _ => v}\n}\n",
      "let f = () => {\nopen M\n\nswitch v {| _ => v}\n}\n" );
    ( "local exception before switch",
      Implementation,
      "let f = () => {\nexception E\nswitch v {| _ => v}\n}\n",
      "let f = () => {\nexception E\n\nswitch v {| _ => v}\n}\n" );
    ( "single-line statements",
      Implementation,
      "let f = () => {input->consume; done()}",
      "let f = () => {input->consume; \n\ndone()}" );
    ( "Unicode",
      Implementation,
      "let value = \"\195\169\240\159\152\128\"->convert\nconsume(value)",
      "let value = \"\195\169\240\159\152\128\"->convert\n\nconsume(value)" );
    ( "multiline trailing comment",
      Implementation,
      "input->consume /* note\ncontinued */\n// next\ndone()\n",
      "input->consume /* note\ncontinued */\n\n// next\ndone()\n" );
    ( "signature nested module",
      Interface,
      "module M: {\nlet a: int\n@deprecated(\"old\")\nlet b: int\n}\n",
      "module M: {\nlet a: int\n\n@deprecated(\"old\")\nlet b: int\n}\n" );
    ( "existing spacing",
      Implementation,
      "input->consume\n  \n\n// next\ndone()\n",
      "input->consume\n  \n\n// next\ndone()\n" );
    ( "nested arguments are not statements",
      Implementation,
      "consume(switch v {| _ => v}, input->convert)\ndone()\n",
      "consume(switch v {| _ => v}, input->convert)\ndone()\n" );
    ( "strings and comments stay opaque",
      Implementation,
      "let text = `switch value\n\
       ->pipe @send external`\n\
       // switch ->\n\
       let value = 0\n",
      "let text = `switch value\n\
       ->pipe @send external`\n\
       // switch ->\n\
       let value = 0\n" );
    ( "comments before annotation",
      Implementation,
      "let a = 0\n/* docs */\n@deprecated(\"old\")\nlet b = 1\n",
      "let a = 0\n\n/* docs */\n@deprecated(\"old\")\nlet b = 1\n" );
    ( "doc comment",
      Implementation,
      "let a = 0\n/** docs */\n@deprecated(\"old\")\nlet b = 1\n",
      "let a = 0\n\n/** docs */\n@deprecated(\"old\")\nlet b = 1\n" );
    ( "JSX switch",
      Implementation,
      "let view = <div>\n\
       <Header />\n\
       {switch value {| _ => <Body />}}\n\
       <Footer />\n\
       </div>\n",
      "let view = <div>\n\
       <Header />\n\n\
       {switch value {| _ => <Body />}}\n\n\
       <Footer />\n\
       </div>\n" );
    ( "JSX fragment pipe",
      Implementation,
      "let view = <>\n{value->render}\n<Footer />\n</>\n",
      "let view = <>\n{value->render}\n\n<Footer />\n</>\n" );
  ]

let recursive_cases =
  [
    ( "recursive binding group",
      Source.Implementation,
      "let rec a = value->convert and b = 1\nconsume(a)\n",
      "let rec a = value->convert and b = 1\n\nconsume(a)\n" );
    ( "constrained next statement",
      Implementation,
      "let f = () => {input->consume; (switch value {| _ => value}: int)}",
      "let f = () => {input->consume; \n\n(switch value {| _ => value}: int)}"
    );
  ]

let () =
  let failures =
    List.filter_map
      (fun (name, kind, input, expected) ->
        match check kind input expected with
        | Ok () -> None
        | Error error -> Some (name ^ ": " ^ Lint_error.render error))
      (cases @ recursive_cases)
  in
  List.iter prerr_endline failures;
  if failures <> [] then exit 1
