# `jsx-a11y/media-has-caption`

Provide captions for audio and video content.

- Category: `correctness`
- Enabled by default: No
- Autofix: No

Include a captions track for spoken content and relevant sounds so it is
available to people who cannot hear the media.

## Examples

### Incorrect
```rescript
let video = <video src="demo.mp4" />
```

### Correct
```rescript
let video = <video src="demo.mp4"> <track kind="captions" src="demo.vtt" /> </video>
```

## Configuration

```json
{"jsxRuntime":"react-dom","rules":{"jsx-a11y/media-has-caption":true}}
```

Run `npx rescript-lint --config rescript-lint.json src/Example.res`.
Set the rule to `false` to disable it.

## Limitations

Requires `react-dom`. Static descendant tracks are detected; dynamic children,
spreads, and custom components can make the result uncertain. Muted media is
excluded by the implementation.

See [JSX accessibility analysis boundaries](../EXTENDED_RULES.md#jsx-accessibility)
and [compiler-audited examples](../RULE_EXAMPLES.md#media-has-caption).
