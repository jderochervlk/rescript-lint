let files config files =
  match (files, (Rule_config.options config).root) with
  | [], Some root ->
      Project_files.discover ~root
        ~excluded:(Rule_config.options config).excluded_paths
  | _ -> Ok files
