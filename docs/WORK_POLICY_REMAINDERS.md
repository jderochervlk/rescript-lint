# Policy Remainder Audit

## Scope and Evidence

Read-only audit of the original contracts in `docs/RULE_CANDIDATES.md`, the
shipped syntax policies, project discovery, configuration, and linter entry
points. Applied functional-code-style and writing-functions. This audit changes
documentation only; implementation must wait for root authorization after the
current packaging and push gates.

## Disposition

| Requirement | Status | Evidence and bounded interpretation |
| --- | --- | --- |
| Intentional empty-function allowance | Implemented | Candidate says configuration **or** annotation. `Policy_rules.empty_body` exempts explicit unit return constraints; tests cover `(): unit => ()` and a typed no-op block. No additional configuration is required to satisfy that wording. |
| Empty declaration-only files | Implemented | `no-empty-file` excludes `.resi` documents. It does not guess whether a `.res` file is declaration-only. |
| Function line limits exclude declarations | Implemented | The limit visits actual function expressions, not ordinary signature declarations, external declarations, or top-level physical lines. |
| Configured generated paths in project discovery | Implemented, discovery-only | `exclude: ["src/generated"]` uses exact relative-path or slash-delimited descendant prefixes in `Project_files.excluded_path`; project discovery and project loading honor it. Existing project tests include a generated directory. |
| Selective generated-file policy exemptions | Outstanding | Explicit CLI filenames bypass `Inputs` discovery, and LSP passes opened sources directly to the linter. Neither route applies discovery exclusions as per-rule policy. Excluding a directory also removes its modules from the project semantic context, which is different from selectively disabling style policies on its sources. |
| Registry file overrides | Outstanding | `Rule_config` has one enabled-ID set and one options record. `Config_file` has no overrides decoder, and the linter has no per-source effective rule configuration. |
| Automatic generated-file/header detection | Not required; do not add | Candidate wording permits explicitly configured generated files. Root approved path-based rule overrides; filename guesses, default marker recognition, and automatic all-rule suppression are unnecessary. |

The existing exclusion mechanism is enough when the intended workflow is solely
project discovery and the user deliberately wants those files omitted from the
whole index. It is not a universal generated-code exemption. Existing paths are
literal prefixes, not globs; normalization variants such as `./src/generated`
must not be assumed equivalent to `src/generated` under the current matcher.

## Proposed Bounded Contract

Add explicit file overrides containing path selectors and rule booleans only:

```json
{
  "root": ".",
  "overrides": [
    {
      "paths": ["src/generated"],
      "rules": {
        "no-empty-file": false,
        "max-lines-per-function": false,
        "require-license-header": false
      }
    }
  ]
}
```

- A selector matches an exact path or descendants after a `/` boundary.
  `src/generated` does not match `src/generated-old`. No glob, regex, negation,
  brace expansion, implicit generator-name matching, or wildcard rule IDs.
- Recommended anchoring: resolve relative selectors against the configured
  project root when present, otherwise the defining config file's directory.
  Resolve that anchor from the completed config object, not JSON key order;
  store the resolved selectors with the entry. Later CLI/config root changes
  must not silently rebase an already decoded override. Absolute selectors can
  remain explicit absolute paths. This anchoring decision is a prerequisite,
  not existing behavior.
- Normalize `.` and separators at the configuration boundary. Reject empty
  selectors, `..` traversal, and wildcard syntax rather than interpreting them
  inconsistently. Use normalized absolute source paths for comparison across
  CLI, project discovery, and LSP; specify symlink behavior consistently with
  `Project_files.canonical`, including its nonexistent-path fallback.
- Require a nonempty paths array and nonempty rules object. Reject unknown or
  duplicate entry properties, wrong types, duplicate selectors, unknown rule
  IDs, duplicate rule keys, and nonboolean rule values.
- Base global rules apply first; matching overrides apply in list order, with
  the last matching explicit value for an ID winning. Document this precedence
  for command-line rule flags too: they configure the base, not an implicit
  final per-file override. Multiple config-file override arrays should replace
  the previous array, consistent with complete structured policy replacement.
- Do not permit overriding project root, exclusions, dependency inventories,
  adapters, thresholds, or other options in this first batch. Do not suppress
  syntax/I/O/analysis failures or remove the matched source from the index.
- Generated exemptions are only the explicitly named policy rules. Other
  enabled safety rules continue to run, and project consumers remain available.
- No generated header detector is needed. If a future user specifically needs
  header selection, the smallest defensible extension is an exact configured
  line in a parsed leading comment before declarations, attached to explicit
  rule booleans. It must not inspect strings, infer a standard marker, or mean
  disable-all. That extension remains unrequested and unimplemented.

## Integration and Risk

The prerequisite is one source-aware effective-rule operation, for example
`Rule_config.for_file ~filename config`, used at the shared linter entry point
before rule activation and adapter/project prerequisite checks. Applying only a
final diagnostic filter is insufficient: a disabled project/adapter rule could
otherwise still produce an analysis failure. Use the same effective config for
checks and final filtering.

Keep the global known-rule registry unchanged for suppression validation;
per-file activation must not redefine which rule IDs are recognized. Adapter
selection remains an explicit global option. Enabling an adapter-dependent rule
through an override must still require its configured adapter, exactly as
global activation does. Fix passes and LSP overlays should use the shared source
entry point so policy cannot diverge between modes.

Expected size is a bounded medium infrastructure change: one pure selector and
override model, one strict decoder, and focused changes to rule config/project
options plus the common linter boundary. It should not require new dependencies
or separate rule implementations. Primary risks are path anchoring and
normalization, precedence across config layers, premature adapter errors,
accidentally dropping project context, and differences among CLI/fix/watch/LSP.

Acceptance tests should cover exact and descendant matches, sibling-prefix
nonmatches, relative/absolute and nonexistent overlay paths, invalid selectors,
multiple matching entries and config layers, disabled and newly enabled rules,
unaffected safety findings, adapter prerequisite errors, suppression known-ID
auditing, retained project consumers, fix verification, and explicit-file/LSP
parity. Preserve existing discovery exclusions as a separate contract.

## Verification Record

- Audit performed by reading the listed implementation and nearby tests; no
  production edits, builds, or new runtime claims were made.
- Root reported the preceding JSON/warning/dependency/watch batch's full checks
  and coverage passing at 95.47% overall. That result verifies the preceding
  implementation, not the proposed override feature.

## Subsequent Authorized Batch

Root later authorized implementation, recorded in `WORK_FILE_OVERRIDES.md`.
The approved contract anchors every selector to the defining config directory,
regardless of project root; this supersedes the project-root fallback proposal
above. Ordered rule-only overrides, replacement arrays, lexical matching,
preserved base rules, and common-linter integration are now implemented and
awaiting that batch's gates. The earlier outstanding table is the audit snapshot,
not a claim that the authorized follow-up remains unimplemented.
