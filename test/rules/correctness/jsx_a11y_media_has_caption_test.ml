let checks_jsx_rules_test_support =
  let open Jsx_rules_test_support in
  [
    ("caption missing", yes "media-has-caption" "<video src=\"demo.mp4\" />");
    ( "audio caption missing",
      yes "media-has-caption" "<audio src=\"demo.mp3\" />" );
    ( "nonmedia does not need captions",
      no "media-has-caption" "<img alt=\"Profile\" />" );
    ( "sibling captions do not satisfy media",
      yes "media-has-caption" "<> <video /> <track kind=\"captions\" /> </>" );
    ( "nested captions remain recognized",
      no "media-has-caption"
        "<video> <div> <track kind=\"captions\" /> </div> </video>" );
    ( "caption provided",
      no "media-has-caption"
        "<video> <track kind=\"captions\" src=\"demo.vtt\" /> </video>" );
    ("muted media", no "media-has-caption" "<video muted=true />");
    ("dynamic captions", no "media-has-caption" "<video> {tracks} </video>");
    ("custom captions", no "media-has-caption" "<video> <Captions /> </video>");
    ( "dynamic track kind",
      no "media-has-caption" "<video> <track kind={kind} /> </video>" );
    ( "wrong track kind",
      yes "media-has-caption" "<video> <track kind=\"subtitles\" /> </video>" );
  ]

let () = Rule_test_runner.run checks_jsx_rules_test_support
