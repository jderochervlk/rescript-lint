# Next Milestone Prompt

Use the following prompt after the configuration and policy expansion PR is
merged, or in a checkout containing that PR's changes:

```text
Continue work in /home/josh/Dev/rescript-linter. Implement the next code milestone
end to end: declaration provenance and an opt-in source-root reference restriction
rule. Do not stop after a plan or a small batch; carry the milestone through
implementation, regression tests, documentation, and verification.

First inspect AGENTS.md, the working tree, and docs/PLAN.md,
docs/WORK_CONFIGURATION_AND_RULES.md, docs/CONFIGURATION.md,
docs/POLICY_EXPANSION.md, docs/PR_8351_REVIEW.md, docs/WORK_PROJECT_INDEX.md,
docs/DEPENDENCIES.md, and docs/LSP.md. Confirm this checkout contains the
configuration/policy expansion (123 rules, 12 defaults) and preserve unrelated
changes. Follow the applicable skills and existing OCaml architecture.

Inspect the semantic model/walker, project exports and public signatures,
dependency loading, project context/cache, configuration pipeline, diagnostics,
and nearby tests before choosing the adapter. Project_index is a content-checked
parse cache, not an existing symbol/provenance index. Prefer a bounded extension
of the source/project model if it can establish trustworthy declaration origins.
Do not infer origins from module spelling. Model resolved origins, supported
exemptions, and unavailable analysis explicitly. Ask before adding any production
dependency or expanding the compiler dependency surface.

Define and document which declaration owns a reference, especially public .resi
declarations versus implementations, aliases, re-exports, opens/includes, local
shadows, nested modules, and explicitly configured dependencies. Public interfaces
remain authoritative; hidden implementation declarations must not leak. Unknown
module types and functor results must not become guessed identities. If compiler
artifacts are necessary, enforce version/freshness checks and define unsaved LSP
buffer behavior before relying on them. Missing required metadata for an enabled
rule is an explicit analysis failure, never a silently clean result.

Implement an opt-in source-root restriction rule with a precise documented ID and
configuration contract. Roots are config-relative, canonicalized through realpath,
and matched at directory boundaries. The first matching configured root controls
the finding; a consumer is exempt only inside that particular root, not inside
any configured root. Start with value and type references, not module references,
constructors, or record-field access. Define missing/unreadable roots and symlink
behavior explicitly. Preserve the existing restrictedModules/restrictions contract.

Integrate strict decoding, the generated npm schema, effective-config inspection
and prerequisites, rule activation/per-file overrides, auditable suppressions,
human/JSON/LSP metadata, and project/watch/LSP operation as applicable. Keep syntax
rules build-independent, defaults unchanged, byte ranges accurate, and unsupported
analysis visible. Add no semantic autofixes in this milestone.

Test allowed/forbidden references, same-root exemptions, overlapping roots,
sibling-prefix directories, symlinks, .res/.resi precedence, aliases, opens,
includes, re-exports, shadows, dependencies, missing/stale inputs, configuration
origins, suppression behavior, deterministic reporting, watch invalidation, and
unsaved overlays. Include compiler-checked valid/invalid catalog examples for
the new rule. Aim for 100% coverage; preserve every existing coverage gate.

Run focused checks while iterating, then make check coverage, the release @install
build, the compiler-backed rule catalog, schema validation, and the affected npm
tests/rebuild/package smoke gates. Update plans and rule/configuration contracts
to distinguish implemented behavior from limitations and record actual results.
Do not claim live Zed validation or release publication. Defer alias avoidance,
single-use helpers, semantic rewrites, and unrelated rule expansion. Finish with
the implementation summary, verification results, and remaining boundaries;
do not commit, push, publish, or open a PR unless I explicitly ask.
```
