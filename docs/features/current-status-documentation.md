# Current status documentation

Created: 2026-11-17
Last updated: 2026-11-17
Status: Implemented
Issue: none

## Purpose and supported behavior

The project roadmap and canonical backlog distinguish implemented behavior,
remaining work, explicit analysis limits, and historical planning. Mutable public
release facts are recorded with an observation date and a link to their source,
not described as perpetual latest values.

The 2026-11-17 release snapshot in
[FOLLOW_UPS.md](../planning/FOLLOW_UPS.md) records the checkout version/catalog,
npm dist-tags, integration repositories, and native target list observed on that
date. Consult the linked live sources and package/release guidance before relying
on those mutable facts later.

## Usage

Maintain [FOLLOW_UPS.md](../planning/FOLLOW_UPS.md) as the active project
backlog. [PLAN.md](../planning/PLAN.md) retains historical roadmap intent and
points readers to the canonical backlog. Keep technical analysis guarantees and
unsupported cases explicit in their authoritative documents, such as the
[unsafe API inventory](../rules/UNSAFE_APIS.md).

## Design and boundaries

Registry tags can move independently from a checkout; every tag claim here is a
dated observation. Native package targets do not imply support for excluded
platforms or ABIs. Separate editor integrations are maintained in separate
repositories. This documentation does not establish editor interoperability or
expand the static analysis guarantees.

## Validation

On 2026-11-17, live npm registry metadata reported `alpha` as
`0.1.0-alpha.22`, `latest` as `0.1.0-alpha.1`, and five optional platform
packages. The checkout `npm/package.json` was `0.1.0-alpha.24`; `npm/targets.json`
listed Linux glibc x64/ARM64, macOS x64/ARM64, and Windows x64. GitHub repository
metadata confirmed the separate `jderochervlk/rescript-lint-vscode` and
`jderochervlk/rescript-lint-zed` repositories.

Validation for the documentation change:

- `git diff 2f105ecd9d2a0fb42149a0f39e64dbeef8c9cd0c...HEAD --check` passed.
- `python3 -c 'from pathlib import Path; import re,sys; files=[Path(p) for p in ["CONTRIBUTING.md","docs/README.md","docs/planning/FOLLOW_UPS.md","docs/planning/PLAN.md","docs/rules/UNSAFE_APIS.md","docs/features/current-status-documentation.md"]]; errors=[f"{f}: missing {target}" for f in files for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)",f.read_text()) if not target.startswith(("http://","https://","#","mailto:")) and target.split("#",1)[0] and not (f.parent/target.split("#",1)[0]).resolve().exists()]; print("\n".join(errors) if errors else f"Checked relative Markdown links in {len(files)} changed documents: all resolve."); sys.exit(bool(errors))'` passed; all local link targets exist.
- `make check` was attempted but could not run because the environment lacks
  `dune`: `opam exec -- dune build @all @check @fmt` returned
  `[ERROR] Command not found 'dune'` (exit 127).

These outcomes apply to the documentation revision only; the OCaml checks are
not reported as passing.

## Historical planning record

### Reconcile current status documentation

Plan created: 2026-11-17
Plan last updated: 2026-11-17

Original committed plan:

> # Reconcile current status documentation
>
> Created: 2026-11-17
> Last updated: 2026-11-17
> Status: Planned
> Issue: none
> Feature documentation: pending
>
> ## Problem and intended outcome
>
> Canonical project status, contribution guidance, and the unsafe API inventory
> contain historical release claims as if they were current or future behavior.
> Update only those owned documents against the current checkout and dated live
> registry/repository evidence, while retaining genuine analysis limitations and
> historical implementation context.
>
> ## Scope and non-goals
>
> Update `docs/planning/FOLLOW_UPS.md`, `docs/planning/PLAN.md` as needed,
> `CONTRIBUTING.md`, and `docs/rules/UNSAFE_APIS.md`. Add the required living
> feature documentation for this documentation-maintenance behavior.
> Do not edit editor docs, release docs, automatic alpha staging docs or its plan,
> source code, or unrelated documentation.
>
> ## Approach and decisions
>
> Keep active follow-ups separate from completed/historical milestones. Phrase
> registry tag and release facts as an observation dated 2026-11-17, cite the npm
> registry endpoint, and avoid presenting a mutable tag/version as a perpetual
> latest. Describe current integration repositories and native targets with
> repository links. Retain the unsafe-analysis limitations only where they remain
> true; remove module alias/open limitations already addressed.
>
> ## Implementation steps
>
> - [ ] Commit this plan before changing the status documentation.
> - [ ] Reconcile release status, follow-ups, and roadmap milestones to current
>   checkout and live evidence.
> - [ ] Correct contributor target/CI statements and unsafe API analysis limits.
> - [ ] Record delivered documentation policy in feature documentation and update
>   this plan with results.
> - [ ] Run documentation/link checks and `make check` if applicable.
> - [ ] Review scope and open an independent PR without merging.
>
> ## Validation
>
> Acceptance: only the scoped documentation changes are present; internal links
> resolve; dynamic external release facts have an observation date; no stale
> current-state claims remain in the owned documents.
>
> Planned: link/reference check, `git diff --check`, and repository-required
> `make check` unless an environment blocker makes it inapplicable or impossible.
> Record exact commands and outcomes after running them.
>
> ## Open questions and remaining work
>
> None. Public release facts observed from the npm registry on 2026-11-17:
> `alpha` is `0.1.0-alpha.22`, `latest` is `0.1.0-alpha.1`; package metadata
> includes five native targets (Linux glibc x64/ARM64, macOS x64/ARM64, Windows
> x64). Verify repository integration names and links before documenting them.

Implementation completed without source changes. Follow-up wording retains
documented analysis boundaries and does not claim compiler-equivalent inference.
