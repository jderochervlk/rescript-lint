type input = {
  uri : string;
  path : string;
  language_id : string;
  version : int;
  text : string;
}

type update_error =
  | Version_not_newer of { current_version : int; received_version : int }

type t = {
  uri : string;
  language_id : string;
  version : int;
  source : Source.t;
  positions : Lsp_position.t;
}

let create (input : input) =
  Result.map
    (fun source_kind ->
      {
        uri = input.uri;
        language_id = input.language_id;
        version = input.version;
        source =
          Source.
            { filename = input.path; text = input.text; kind = source_kind };
        positions = Lsp_position.create input.text;
      })
    (Source.kind_of_filename input.path)

let update ~version ~text document =
  if version <= document.version then
    Error
      (Version_not_newer
         { current_version = document.version; received_version = version })
  else
    Ok
      {
        document with
        version;
        source = { document.source with text };
        positions = Lsp_position.create text;
      }

let uri document = document.uri
let language_id document = document.language_id
let version document = document.version
let source document = document.source
let positions document = document.positions

let render_update_error = function
  | Version_not_newer { current_version; received_version } ->
      Printf.sprintf "Document version %d is not newer than current version %d."
        received_version current_version
