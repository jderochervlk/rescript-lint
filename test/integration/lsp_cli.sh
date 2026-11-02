#!/usr/bin/env bash
set -euo pipefail

frame() {
  printf 'Content-Length: %d\r\n\r\n%s' "${#1}" "$1"
}

initialize='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"capabilities":{}}}'
initialized='{"jsonrpc":"2.0","method":"initialized","params":{}}'
open_document='{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///workspace/DocLinks.res","languageId":"rescript","version":1,"text":"Console.log(1)"}}}'
shutdown='{"jsonrpc":"2.0","id":2,"method":"shutdown"}'
exit_message='{"jsonrpc":"2.0","method":"exit"}'

output=$(
  {
    frame "$initialize"
    frame "$initialized"
    frame "$open_document"
    frame "$shutdown"
    frame "$exit_message"
  } | rescript-lint lsp --stdio
)

printf '%s' "$output" | grep -o '"positionEncoding":"utf-16"'
printf '%s' "$output" | grep -o '"serverInfo":{"name":"rescript-lint","version":"[^"]*"}'
printf '%s' "$output" | grep -o '"codeDescription":{"href":"https://github.com/jderochervlk/rescript-lint/blob/main/docs/rules/no-console.md"}'
printf '%s' "$output" | grep -o '"id":2,"jsonrpc":"2.0","result":null'
