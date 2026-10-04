module Documents = Map.Make (String)

type error =
  | Already_open of { uri : string }
  | Not_open of { uri : string }
  | Update_rejected of { uri : string; reason : Lsp_document.update_error }

type t = Lsp_document.t Documents.t

let empty = Documents.empty
let count = Documents.cardinal
let find ~uri documents = Documents.find_opt uri documents

let open_document document documents =
  let uri = Lsp_document.uri document in
  if Documents.mem uri documents then Error (Already_open { uri })
  else Ok (Documents.add uri document documents)

let change ~uri ~version ~text documents =
  match Documents.find_opt uri documents with
  | None -> Error (Not_open { uri })
  | Some document -> (
      match Lsp_document.update ~version ~text document with
      | Ok updated -> Ok (updated, Documents.add uri updated documents)
      | Error reason -> Error (Update_rejected { uri; reason }))

let close ~uri documents =
  match Documents.find_opt uri documents with
  | None -> Error (Not_open { uri })
  | Some document -> Ok (document, Documents.remove uri documents)

let render_error = function
  | Already_open { uri } -> Printf.sprintf "Document is already open: %s" uri
  | Not_open { uri } -> Printf.sprintf "Document is not open: %s" uri
  | Update_rejected { uri; reason } ->
      Printf.sprintf "Cannot update %s: %s" uri
        (Lsp_document.render_update_error reason)
