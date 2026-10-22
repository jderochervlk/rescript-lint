---
name: opening-pull-requests
description: Open or draft GitHub pull requests with repository-aware conventional titles and concise, natural descriptions. Use when Codex is asked to create, open, submit, or prepare a pull request.
---

# Opening Pull Requests

Inspect the final diff, commit history, repository conventions, and any linked issue before writing the pull request. This repository is an OCaml CLI and library built with Dune, with an npm launcher and native packages. Apply the repository's Git and stack workflow, including the `gh-stacked-prs` skill when available; this skill governs the PR title and description, not branch or publication mechanics.

## Title

Use this exact shape:

```text
type(scope): concise imperative summary [Codex]
```

- Follow Conventional Commits for the type. Prefer the repository's configured types; otherwise use the conventional type that best describes the primary change, such as `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `perf`, `build`, or `ci`.
- Use a concise repository scope that describes the primary change. Existing scopes include `linter` and `rescript-lint`; module-area scopes such as `rules`, `cli`, `config`, `lsp`, `npm`, `docs`, and `ci` are appropriate when they make the change clearer.
- For changes spanning areas, choose the narrowest honest scope. Do not use a page or monorepo-project scope; this repository has neither.
- Keep the summary specific, concise, and imperative. Do not end it with punctuation.
- Always append `[Codex]` as the final text in the title.

Example:

```text
feat(linter): add source-root validation [Codex]
```

## Description

Write for a maintainer who needs to understand why the change exists and what it does. Include:

- the issue or user-facing problem being addressed, including relevant context or constraints;
- the solution and why it addresses that problem;
- a concise but reasonably detailed summary of the meaningful changes.

Use short paragraphs and small, descriptive sections only when they improve readability. Mention affected OCaml modules, CLI or diagnostic behavior, configuration changes, generated Opam metadata, or compatibility implications when relevant. For packaging changes, identify which npm launcher or native-package behavior changes. Link the issue when one exists and the link is known.

Do not add a tests, verification, checklist, or CI section; successful CI checks are the verification record. Do not invent issue links, motivations, results, or implementation details that are not supported by the diff or task context.

Keep the prose direct and natural. Avoid AI self-reference, canned framing, inflated claims, excessive headings, repetitive restatement of the title, and phrases such as "This PR aims to," "comprehensive," or "robust solution."

Before opening the PR, run `make check` for OCaml changes. For npm packaging changes, run the relevant npm checks documented in `CONTRIBUTING.md`. Verify that the title describes the actual primary change, the scope matches the repository conventions, `[Codex]` is last, and the description matches the final diff. Opening or updating the PR is a remote mutation; do it only when the user's request authorizes that action.
