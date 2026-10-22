---
name: gh-stacked-prs
description: Manage GitHub stacked pull requests and protect concurrent work on their branches and worktrees. Use when the user explicitly requests a stacked-PR workflow or when a read-only repository-wide preflight confirms that the target branch or PR belongs to an existing locally tracked stack. Do not use merely because a task involves Git, worktrees, or an ordinary pull request.
---

# GitHub Stacked Pull Requests

Most pull requests are ordinary pull requests and should remain ordinary. A repository can contain stacked and unstacked PRs at the same time, and the existence of one stack does not make every branch or PR part of it. Use a stack only when the user explicitly requests one, the target already belongs to one, or dependent changes are intentionally being split into a stack with the user's authorization.

For confirmed stacks, use `gh stack` as the owner of stack topology and cascading history. Keep each change on the branch for the PR that owns it, then propagate rewritten history upward with stack-aware commands.

## Checks For This Repository

This project is an OCaml 5.5 codebase built with Dune. After OCaml changes, run the narrowest relevant test while iterating and run `make check` before publishing; it covers the build, formatting check, and tests. Follow `CONTRIBUTING.md` for generated Opam metadata and npm or native-package checks when those areas change. Keep each stack layer focused and run checks again after rebasing or resolving conflicts.

## Decide Whether This Skill Applies

Before using this skill for otherwise ordinary Git or PR work, perform a minimal read-only preflight to determine whether the target branch or PR belongs to a locally tracked stack. Linked worktrees share stack tracking state and a recovery journal; there is no single stack-owning worktree. Stack commands can update clean affected worktrees, so locate each branch's checkout and inspect all affected worktrees. Start with:

```sh
git status --short
git branch --show-current
git worktree list --porcelain
gh stack view --json
```

Always use `gh stack view --json` for parsed agent inspections or `gh stack view --short` for human-readable output. Bare `gh stack view` opens a full-screen TUI under a PTY and can block an agent terminal.

Treat exit code 2 from `gh stack view --json` as "the current branch is not in a locally tracked stack, or the stack was not found" rather than as proof that the repository has no stack. Run read-only `gh stack view --short` inspections from the existing worktree paths reported by `git worktree list --porcelain` to inspect their checked-out branches against the shared tracking state. Record any stacks found, then determine whether the target branch or PR belongs to one before editing.

- Do not infer that the target belongs to a stack from branch names, multiple worktrees, multiple open PRs, or the existence of a different stack in the repository.
- If the target does not belong to an existing stack and the user did not request a new stack, stop applying this skill and use the repository's ordinary Git and PR workflow.
- If the target belongs to a locally tracked stack, use the stack-aware navigation, rewrite, synchronization, publication, and structural commands in this skill.
- For read-only Git actions such as `status`, `diff`, `log`, `show`, or `blame`, do not add unnecessary stack commands after stack membership is known unless stack topology affects the answer.
- Do not convert an unstacked branch or ordinary PR into a stack, install `gh stack`, or mutate remote stack state merely because this skill is available or another stack exists. Do so only when the user requests or authorizes stack behavior.
- When `gh stack` is unavailable and the requested action is ordinary unstacked Git work, continue with Git. Ask about installation only when stack-specific behavior is required.

## Coordinate Concurrent Stack Work

Assume multiple agents may be working on different stack layers at the same time. Once the target work is confirmed to belong to a stack:

- Work through that existing stack and its existing branch worktrees. Never create a worktree, delete or prune a worktree, make a temporary checkout, create a temporary clone, or use detached HEAD to obtain another workspace for that stack work.
- Never route confirmed stack work onto an unstacked branch or backup worktree merely because it is currently checked out or clean. Locate the owning layer in the existing stack.
- Reuse the target branch's existing worktree when it has one. Otherwise, use `gh stack` for navigation from an existing clean worktree only when moving layers will not disrupt concurrent work.
- Treat unrelated modified, staged, or untracked files in any affected worktree as active work owned by another agent. Do not edit, stage, stash, commit, restore, discard, move, or otherwise absorb those files. A clean current worktree alone does not make a stack-wide operation safe.
- When unrelated edits exist, do not switch branches, rebase, modify stack structure, sync, push, submit, or run any command that could rewrite or publish another agent's work.
- Change the immediate task to a read-only verification pass: inspect the stack topology, branch positions, working-tree state, local-versus-tracking state, and whether the stack appears up to date. Clearly distinguish facts verified against current remote-tracking refs from freshness that would require a fetch.
- After reporting the verification and accounting for all unrelated edits, explicitly ask whether the active agents are ready to commit their respective changes and synchronize/push the stack upward. Do not commit or run `gh stack sync`, `push`, or `submit` until the user confirms readiness.
- If the requested owning layer cannot be reached safely inside the existing stack because another agent's edits are present, stop after verification and ask for coordination. Do not manufacture an isolated workspace as a workaround.

GitHub stacked PRs and `gh stack` are in public preview. Before relying on an unfamiliar flag or recovering from an undocumented state, run `gh stack <command> --help` and consult the current [GitHub CLI command reference](https://docs.github.com/en/pull-requests/reference/stacked-prs-cli-commands).

## Establish the State

1. Verify the tools and authentication:

   ```sh
   gh stack --version
   gh auth status
   ```

   Require a released `gh-stack` version of at least **v0.2.0**, which includes shared cross-worktree operation and `merge`. Parse the semantic version from `gh stack --version` into numeric major, minor, and patch components and compare that tuple with `(0, 2, 0)`; command success or a lexicographic string comparison is not sufficient. If the version is older, unparseable, a development build, or a prerelease, stop and ask before running `gh extension upgrade stack`, then recheck. Do not run stack mutations until this check passes. See the [release history](https://github.com/github/gh-stack/releases) before raising this minimum or relying on newer behavior.

   If `gh stack` is unavailable, ask before installing the production tool, then use `gh extension install github/gh-stack` and apply the same version check. Stacks require all branches to be in the same repository; cross-fork stacks are unsupported.

2. Inspect before editing or switching:

   ```sh
   git status --short
   git branch --show-current
   gh stack view --json
   ```

   Use `gh stack view --short` only when human-readable output is sufficient; never use bare `view` for an agent inspection. Exit code 2 means the current branch is not in a locally tracked stack or the stack was not found.

3. Identify the exact target branch and its position. Never infer stack order from PR numbers, branch names, or creation dates.

4. Check `git worktree list --porcelain` before switching. Map each affected stack branch to its actual worktree, if checked out, and inspect those worktrees before a stack-wide operation. A branch already checked out in another worktree must be edited there; do not look for a sole owner of the shared stack state. Never add, remove, prune, or temporarily create a worktree for the stack. If the target is not a stack member, continue with the ordinary workflow while preserving existing worktrees.

5. Preserve user work. Do not stash, discard, move, rebase, or commit unrelated changes. Require a clean tree before `sync`, `rebase`, or `modify`, unless the active operation explicitly expects staged conflict resolutions.

6. Select one publication remote before any fetch or stack mutation. Inspect `git remote -v` and `git config --get remote.pushDefault`; verify the chosen remote points to the intended GitHub repository, not a local-checkout backlink. In the examples below, replace `<remote>` with that exact name for both Git verification and stack commands. Always pass `--remote <remote>` to `push`, `submit`, `sync`, `rebase`, and `link`, including recovery invocations. `checkout` and `trunk` do not accept `--remote`; in a multi-remote clone they require `remote.pushDefault` to name the same verified remote. If that setting is absent or differs, ask before changing it and stop those operations until it is consistent. Do not rely on automatic remote selection or verify one remote and publish to another.

## Guardrails

- Prefer `gh stack checkout`, `switch`, `up`, `down`, `top`, `bottom`, and `trunk` over ordinary checkout for stack navigation.
- Never use `gh pr checkout` to establish local stack tracking. Use `gh stack checkout`.
- Never use raw `git rebase`, `git push --force`, or manual branch rewrites for a tracked stack. Use `gh stack rebase` and stack-aware publication, subject to the remote-work safety check below; lease checks alone do not preserve remote-only commits.
- Do not make a lower-layer fix on the top branch. Check out the owning branch, commit there, rebase the upstack, and push every affected branch.
- Treat `gh stack sync` as a remote-mutating command, not a read-only pull. It fetches, reconciles, may rebase, pushes active branches, and updates remote stack state.
- Treat `submit`, `push`, `sync`, `link`, `merge`, and remote `unstack` as remote mutations. Run them only when the request authorizes the corresponding publication or management action.
- Do not run `gh stack sync --prune` unless deleting local branches for merged PRs is intended.
- After a rewrite, do not push one branch manually. Upstack branches also have new commit IDs and must be updated together.

## Create a Stack

Create a stack only when the user explicitly requests one or authorizes splitting dependent changes into multiple PRs. Do not stack an independent change merely because the repository already contains a stack.

Create branches from bottom to top. The trunk defaults to the repository default branch; specify `--base` when it should differ.

```sh
gh stack init --base main feature-core
# edit, test, stage specific files, and commit
gh stack add feature-api
# edit, test, stage specific files, and commit
gh stack add feature-ui
# edit, test, stage specific files, and commit
gh stack view --json
gh stack submit --remote <remote> --auto
```

To adopt existing **local** branches, first verify every `refs/heads/<branch>` exists at its intended tip. `init` resolves branches locally and creates missing ones; it does not import remote-only branches. For branches already published, fetch the selected publication remote and compare local and remote tips before proceeding:

```sh
# Repeat for every branch, using the actual publication remote.
git fetch <remote>
git show-ref --verify refs/heads/feature-core
git rev-parse refs/heads/feature-core refs/remotes/<remote>/feature-core
```

Stop if a local ref is missing or the tips differ; inspect and reconcile the histories rather than letting `init` create a replacement. For existing remote PRs, prefer `gh stack link --remote <remote> <bottom-pr> <next-pr> ...` followed by `gh stack checkout <stack-number-or-pr>` with the verified default remote; for an existing remote stack, use `checkout` directly. Only after all local tips are verified, list the branches in bottom-to-top order:

```sh
gh stack init --base main feature-core feature-api feature-ui
gh stack view --json
gh stack submit --remote <remote> --auto
```

Use interactive `gh stack submit --remote <remote>` only in a user-operated terminal when titles, descriptions, inclusion, and draft status need review. In an agent terminal, including one backed by a PTY, use `gh stack submit --remote <remote> --auto`; this creates new PRs as drafts unless `--open` is also passed. Confirm the desired review state before using `--open`.

`--auto` skips the title editor and generates titles from commit subjects or branch names; it does not complete this repository's PR-opening workflow. After any submission that creates PRs, inspect every new PR's title, body, base, and draft state with `gh pr view`. Follow `.agents/skills/opening-pull-requests/SKILL.md` and normalize each title to `type(scope): summary [Codex]`, for example with `gh pr edit <number> --title 'feat(linter): add source-root validation [Codex]'`. Review and update each body as required by that skill, then verify the final metadata. Do not assume generated titles already comply.

`submit` pushes every branch, creates missing PRs, sets the correct chained base branches, and creates or updates the stack on GitHub.

## Add a PR to a Stack

For a locally tracked stack, add new work only from the top branch:

```sh
gh stack top
gh stack add feature-next
# edit, test, stage specific files, and commit
gh stack submit --remote <remote> --auto
```

`gh stack add` creates and checks out a branch at the current top. Avoid its `-A` or `-u` commit shortcuts unless all selected working-tree changes were inspected and belong to the new layer.

To append existing branches or PRs without local stack tracking, use `link`:

```sh
# Create a remote stack; arguments are bottom to top.
gh stack link --remote <remote> 101 102 feature-ui

# Append to remote stack 7 without repeating its existing PRs.
gh stack link --remote <remote> 7 103 feature-ui
```

`link` is remote-only and additive. It can push branches, create missing PRs, and correct chained base branches, but it does not create local tracking and never removes existing PRs from a stack. Use `gh stack checkout <stack-number-or-pr>` first when ongoing local management is required.

## Pull the Latest Stack

To establish a local copy of a remote stack, use a stack number, PR number, PR URL, or branch name. For a branch name, `checkout` first checks local tracking, then searches remote stacks and pulls the unique match. If the lookup is ambiguous, identify the intended stack or PR rather than guessing:

```sh
gh stack checkout <stack-number-or-pr-number-or-url-or-branch>
gh stack view --json
```

For an existing clean local stack, synchronize it:

```sh
gh stack sync --remote <remote>
gh stack view --json
```

`sync` fetches the remote, appends clean remote-ahead PRs locally, fast-forwards the trunk, cascades a rebase if the trunk moved, pushes active branches, synchronizes PR state, and refreshes the remote stack object. After lower PRs merge, use `gh stack sync --remote <remote> --prune` only when local deletion of their merged branches is desired.

If local and remote stack compositions diverged, do not guess. In an interactive terminal, choose among remote-as-source-of-truth, deleting only the remote stack object for later recreation, or canceling. In a non-interactive terminal, divergence can stop without updating anything while returning exit code 0. Always verify the resulting composition with `gh stack view --json`; never treat the exit code alone as proof of synchronization.

If `sync` detects a rebase conflict, it restores all branches. Resolve through the explicit workflow, applying the remote-work safety check below before the final push:

```sh
gh stack rebase --remote <remote>
# resolve files, stage only the resolutions
gh stack rebase --remote <remote> --continue
gh stack push --remote <remote>
```

Use `gh stack rebase --remote <remote> --abort` to restore the entire stack to its pre-rebase state.

## Change a PR in the Stack

1. Start clean, inspect the stack, and check out the branch for the PR being changed:

   ```sh
   git status --short
   gh stack view --json
   gh stack checkout <target-branch>
   ```

   Before rewriting history, fetch the publication remote and record each affected branch's local and remote tip SHAs. Inspect any remote-ahead or diverged history and reconcile it before editing; keep these pre-rewrite tips for the publication safety check.

2. Make the focused change, run the affected checks, stage only intended files, and commit it on that branch.

3. If the target is below another active layer, cascade the change through every branch above it:

   ```sh
   gh stack rebase --remote <remote> --upstack
   ```

   For a top-layer-only commit, no upstack rebase is needed. If the trunk or an unknown lower layer also moved, use a full `gh stack rebase --remote <remote>` instead.

4. Resolve a conflict by editing the reported files, staging the resolutions, and continuing with `gh stack rebase --remote <remote> --continue`. Use the stack command, not `git rebase --continue`. Re-run relevant checks after history is rebuilt.

5. Apply the remote-work safety check below, then publish all affected branches and verify:

   ```sh
   gh stack push --remote <remote>
   gh stack view --json
   git status --short
   ```

### Remote-work safety before publication

Do not rely on `push` rejecting remote-only commits. It fetches before constructing its leases, so the newly fetched SHA can authorize overwriting work that the local branch never incorporated ([upstream issue #380](https://github.com/github/gh-stack/issues/380)). Until that behavior is fixed and verified in the installed version, apply this check before every standalone `push` and before `submit` or another operation that pushes existing branches:

- Coordinate a publication window that excludes all other remote writers, including CI bots and other automation, throughout verification and publication. If that cannot be guaranteed, stop and ask for coordination or a verified safe implementation that leases against the exact remote tips whose histories were checked. Do not disable automation without authorization.
- Prefer an authorized `gh stack sync --remote <remote>` to reconcile remote work before publication. It is itself a remote mutation, so first coordinate all affected worktrees and verify the resulting branch composition and histories, not just its exit code.
- Alternatively, fetch the actual publication remote and verify for **every** affected published branch that its remote tip is an ancestor of the local tip, using `git merge-base --is-ancestor refs/remotes/<remote>/<branch> refs/heads/<branch>`. A missing remote-tracking ref is not proof of a new branch; verify remote existence separately.
- After an intentional rebase, ancestry may fail because commit IDs changed. Do not waive the check merely because a rebase ran. Verify that every remote-only commit was preserved or replayed in the rewritten history, using the recorded pre-rebase tips and a range comparison. If this cannot be established, stop and reconcile through `sync` or ask for coordination.
- Recheck remote tips immediately before publication. If another writer advanced them since verification, stop and reconcile again. This recheck is not a safety guarantee by itself: the fetch-then-lease behavior leaves a race unless other remote writers remain excluded through publication.

`push` is also not atomic: some branches can update while another is rejected. Inspect partial updates, preserve remote work, repeat the safety check, fix the rejected branch, and rerun `gh stack push --remote <remote>`. Do not replace it with a force push.

Use `gh stack submit --remote <remote> --auto` instead of only `push` when the change also adds PRs or changes stack composition. A code or commit update on existing PR branches needs `push`; a structural update needs `submit`.

## Check and Update Every PR

When asked to check, refresh, or finish an entire stack, inspect every active PR from bottom to top. Use `gh stack view --json` to obtain the authoritative PR and branch order; never substitute PR-number or creation-date order. Treat a request to check or inspect as read-only unless it also authorizes updates; report required fixes and draft any needed replies without editing code or GitHub in a read-only pass.

1. Record each PR's number, branch, URL, and current `headRefOid`. Read top-level conversation comments, submitted reviews, and thread-aware review data. Use the GitHub comment-handling workflow when available; otherwise query `reviewThreads` with `gh api graphql` so unresolved and outdated state and inline locations are preserved. Flat comment lists alone are insufficient.

2. Classify every comment. Approvals, informational notes, duplicates, and already-resolved or outdated threads may require no code change, but verify that they are non-actionable. Every actionable comment must receive an explicit disposition:

   - If the suggestion is valid, make the smallest correct fix on the branch for the lowest PR that owns the behavior, run the affected checks, and commit it there.
   - If the suggestion does not work, conflicts with another requirement, or would cause a regression, reply with the concrete technical reason instead of silently skipping it. Do not claim it was fixed.
   - If the comment is ambiguous, ask for clarification or post a clarifying reply rather than guessing.

   Replying to or resolving a GitHub thread is a remote write. Do it only when the user's request authorizes addressing comments. Resolve a thread only after its requested change or agreed disposition is complete; a reply alone does not automatically justify resolution.

3. When updates are authorized, after changing a non-top layer, run `gh stack rebase --remote <remote> --upstack` before continuing upward. Resolve conflicts with the stack rebase workflow, rerun affected checks, and keep each fix on its owning layer. After all local fixes are complete, apply the remote-work safety check above and run one `gh stack push --remote <remote>` to publish every rewritten active branch.

4. Check CI separately for every PR in the stack against its current head commit:

   ```sh
   gh pr view <pr-number> --json headRefOid,statusCheckRollup,url
   gh pr checks <pr-number> --watch
   gh pr checks <pr-number>
   ```

   Do not treat aggregate stack state, an earlier commit's results, or one PR's checks as evidence for another PR. Wait for all expected jobs; require every completed CI job to pass and no job to remain pending, queued, failing, canceled, timed out, or awaiting action. Investigate failures with `gh run view <run-id> --log-failed` and fix the problem on the lowest owning layer.

5. Any new commit, rebase, or push changes one or more PR head commits and invalidates earlier CI evidence for those PRs. Restart comment and CI verification for the changed PR and every affected PR above it. Finish with a second bottom-to-top pass and report, for each PR, its final head commit, comment dispositions, and CI result. Do not report the stack complete while an actionable comment lacks a fix or explanatory reply, or while any expected CI job is not green.

## Manage Stack Structure

Use these inspection and navigation commands:

```sh
gh stack view --json
gh stack view --short
gh stack switch
gh stack up
gh stack down
gh stack top
gh stack bottom
gh stack trunk
```

Use `gh stack modify` to drop, fold, insert, reorder, or rename layers. Before starting, require an active stack, a clean worktree, no rebase, no queued PR, and linear history.

```sh
gh stack rebase --remote <remote>        # first, only if history is not linear
gh stack modify                          # stage operations and save with Ctrl+S
gh stack submit --remote <remote> --auto  # push branches and recreate/update the remote stack
```

The modify UI supports drop (`x`), fold down (`d`), fold up (`u`), insert below/above (`i`/`I`), rename (`r`), reorder (`Shift+Up`/`Shift+Down`), and undo (`z`). Do not mix reordering with structural operations in one session. On conflict, stage resolutions and run `gh stack modify --continue`; use `gh stack modify --abort` to restore the pre-modify snapshot.

Use `gh stack unstack` only with explicit confirmation. It removes local tracking and unlinks eligible PRs on GitHub but preserves their branches and PRs. Merged, merging, or queued PRs remain stacked. Use `--local` to remove only local tracking.

Use `gh stack merge [stack-or-pr-number]` only when explicitly asked to merge. Merging through a chosen PR includes every PR below it. Confirm that each selected PR is open, non-draft, approved, passing required checks, and linearly based before merging.

## Completion Check

Before reporting completion:

1. Run the requested tests and repository checks on the final branch state.
2. When a stack was used, run `gh stack view --json` from an existing worktree on a member branch and confirm branch order, PR association, and current position against the shared stack state.
3. Run `git status --short` in the relevant existing worktrees and account for every remaining change without disturbing concurrent work.
4. State which branch was changed, whether descendants were rebased, and whether `push`, `submit`, `sync`, `link`, or `merge` changed GitHub.
5. Never claim the stack or PRs were updated remotely if only local commits were created.
6. When the task covered the full stack, include a per-PR comment and current-head CI result; do not summarize one passing PR as stack-wide success.

For current behavior and recovery details, consult GitHub's [creating](https://docs.github.com/en/pull-requests/how-tos/create-pull-requests/creating-stacked-pull-requests), [managing](https://docs.github.com/en/pull-requests/how-tos/create-pull-requests/managing-stacked-pull-requests), and [troubleshooting](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-stacked-pull-requests) guides.
