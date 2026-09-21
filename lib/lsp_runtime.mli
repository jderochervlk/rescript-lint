type channels = {
  input : in_channel;
  output : out_channel;
  error : out_channel;
}

val run : dependencies:Lsp_server.dependencies -> channels -> int
