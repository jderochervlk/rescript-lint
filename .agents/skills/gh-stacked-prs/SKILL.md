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

Before using this skill for otherwise ordinary Git or PR work, perform a minimal read-only preflight to determine whether the target branch or PR belongs to a locally tracked stack. Stack tracking is worktree-specific, so checking only the current branch or worktree is insufficient. Start with:

```sh
git status --short
git branch --show-current
git worktree list --porcelain
gh stack view
```

Treat exit code 2 from `gh stack view` as "not locally tracked in this worktree" rather than as proof that the repository has no stack. Run read-only `gh stack view --short` inspections from the existing worktree paths reported by `git worktree list --porcelain`. Record any stacks found, then determine whether the target branch or PR belongs to one before editing.

- Do not infer that the target belongs to a stack from branch names, multiple worktrees, multiple open PRs, or the existence of a different stack in the repository.
- If the target does not belong to an existing stack and the user did not request a new stack, stop applying this skill and use the repository's ordinary Git and PR workflow.
- If the target belongs to a locally tracked stack, use the stack-aware navigation, rewrite, synchronization, publication, and structural commands in this skill.
- For read-only Git actions such as `status`, `diff`, `log`, `show`, or `blame`, do not add unnecessary stack commands after stack membership is known unless stack topology affects the answer.
- Do not convert an unstacked branch or ordinary PR into a stack, install `gh stack`, or mutate remote stack state merely because this skill is available or another stack exists. Do so only when the user requests or authorizes stack behavior.
- When `gh stack` is unavailable and the requested action is ordinary unstacked Git work, continue with Git. Ask about installation only when stack-specific behavior is required.

## Coordinate Concurrent Stack Work

Assume multiple agents may be working on different stack layers at the same time. Once the target work is confirmed to belong to a stack:

- Work through that existing stack and its existing worktree. Never create a worktree, delete or prune a worktree, make a temporary checkout, create a temporary clone, or use detached HEAD to obtain another workspace for that stack work.
- Never route confirmed stack work onto an unstacked branch or backup worktree merely because it is currently checked out or clean. Locate the owning layer in the existing stack.
- Reuse the existing stack worktree and use `gh stack` for navigation only when its worktree is clean and moving layers will not disrupt concurrent work.
- Treat unrelated modified, staged, or untracked files anywhere in the stack worktree as active work owned by another agent. Do not edit, stage, stash, commit, restore, discard, move, or otherwise absorb those files.
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

   If `gh stack` is unavailable, ask before installing the production tool, then use `gh extension install github/gh-stack`. Stacks require all branches to be in the same repository; cross-fork stacks are unsupported.

2. Inspect before editing or switching:

   ```sh
   git status --short
   git branch --show-current
   gh stack view
   ```

   Use `gh stack view --json` when the result must be parsed. Exit code 2 means the current branch is not in a locally tracked stack or the stack was not found.

3. Identify the exact target branch and its position. Never infer stack order from PR numbers, branch names, or creation dates.

4. Check `git worktree list --porcelain` before switching. Inspect existing worktrees for stack ownership and determine whether the target is a member. If it is, operate from that stack's worktree and never add, remove, prune, or temporarily create a worktree for the stack. If it is not, continue with the ordinary workflow while preserving the existing stack worktree. A branch already checked out in another worktree must be edited there.

5. Preserve user work. Do not stash, discard, move, rebase, or commit unrelated changes. Require a clean tree before `sync`, `rebase`, or `modify`, unless the active operation explicitly expects staged conflict resolutions.

## Guardrails

- Prefer `gh stack checkout`, `switch`, `up`, `down`, `top`, `bottom`, and `trunk` over ordinary checkout for stack navigation.
- Never use `gh pr checkout` to establish local stack tracking. Use `gh stack checkout`.
- Never use raw `git rebase`, `git push --force`, or manual branch rewrites for a tracked stack. Use `gh stack rebase` and `gh stack push`, which pushes rewritten branches with lease checks.
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
gh stack view
gh stack submit
```

To adopt existing branches, list them in bottom-to-top order:

```sh
gh stack init --base main feature-core feature-api feature-ui
gh stack view
gh stack submit
```

Use interactive `gh stack submit` when titles, descriptions, inclusion, and draft status need review. In a non-interactive environment, use `gh stack submit --auto`; this creates new PRs as drafts unless `--open` is also passed. Confirm the desired review state before using `--open`.

`submit` pushes every branch, creates missing PRs, sets the correct chained base branches, and creates or updates the stack on GitHub.

## Add a PR to a Stack

For a locally tracked stack, add new work only from the top branch:

```sh
gh stack top
gh stack add feature-next
# edit, test, stage specific files, and commit
gh stack submit
```

`gh stack add` creates and checks out a branch at the current top. Avoid its `-A` or `-u` commit shortcuts unless all selected working-tree changes were inspected and belong to the new layer.

To append existing branches or PRs without local stack tracking, use `link`:

```sh
# Create a remote stack; arguments are bottom to top.
gh stack link 101 102 feature-ui

# Append to remote stack 7 without repeating its existing PRs.
gh stack link 7 103 feature-ui
```

`link` is remote-only and additive. It can push branches, create missing PRs, and correct chained base branches, but it does not create local tracking and never removes existing PRs from a stack. Use `gh stack checkout <stack-number-or-pr>` first when ongoing local management is required.

## Pull the Latest Stack

To establish a local copy of a remote stack, use a stack number, PR number, or PR URL. Branch names resolve only against stacks that are already tracked locally:

```sh
gh stack checkout <stack-number-or-pr-number-or-url>
gh stack view
```

For an existing clean local stack, synchronize it:

```sh
gh stack sync
gh stack view
```

`sync` fetches the remote, appends clean remote-ahead PRs locally, fast-forwards the trunk, cascades a rebase if the trunk moved, pushes active branches, synchronizes PR state, and refreshes the remote stack object. After lower PRs merge, use `gh stack sync --prune` only when local deletion of their merged branches is desired.

If local and remote stack compositions diverged, do not guess. In an interactive terminal, choose among remote-as-source-of-truth, deleting only the remote stack object for later recreation, or canceling. In a non-interactive terminal, divergence can stop without updating anything while returning exit code 0. Always verify the resulting composition with `gh stack view`; never treat the exit code alone as proof of synchronization.

If `sync` detects a rebase conflict, it restores all branches. Resolve through the explicit workflow:

```sh
gh stack rebase
# resolve files, stage only the resolutions
gh stack rebase --continue
gh stack push
```

Use `gh stack rebase --abort` to restore the entire stack to its pre-rebase state.

## Change a PR in the Stack

1. Start clean, inspect the stack, and check out the branch for the PR being changed:

   ```sh
   git status --short
   gh stack view
   gh stack checkout <target-branch>
   ```

2. Make the focused change, run the affected checks, stage only intended files, and commit it on that branch.

3. If the target is below another active layer, cascade the change through every branch above it:

   ```sh
   gh stack rebase --upstack
   ```

   For a top-layer-only commit, no upstack rebase is needed. If the trunk or an unknown lower layer also moved, use a full `gh stack rebase` instead.

4. Resolve a conflict by editing the reported files, staging the resolutions, and continuing with `gh stack rebase --continue`. Use the stack command, not `git rebase --continue`. Re-run relevant checks after history is rebuilt.

5. Publish all affected branches and verify:

   ```sh
   gh stack push
   gh stack view
   git status --short
   ```

`push` updates active, unmerged branches with explicit `--force-with-lease` checks. It is not atomic: some branches can update while another is rejected. Inspect the rejection, preserve remote work, fix the rejected branch, and rerun `gh stack push`. Do not replace it with a force push.

Use `gh stack submit` instead of only `push` when the change also adds PRs or changes stack composition. A code or commit update on existing PR branches needs `push`; a structural update needs `submit`.

## Check and Update Every PR

When asked to check, refresh, or finish an entire stack, inspect every active PR from bottom to top. Use `gh stack view --json` to obtain the authoritative PR and branch order; never substitute PR-number or creation-date order. Treat a request to check or inspect as read-only unless it also authorizes updates; report required fixes and draft any needed replies without editing code or GitHub in a read-only pass.

1. Record each PR's number, branch, URL, and current `headRefOid`. Read top-level conversation comments, submitted reviews, and thread-aware review data. Use the GitHub comment-handling workflow when available; otherwise query `reviewThreads` with `gh api graphql` so unresolved and outdated state and inline locations are preserved. Flat comment lists alone are insufficient.

2. Classify every comment. Approvals, informational notes, duplicates, and already-resolved or outdated threads may require no code change, but verify that they are non-actionable. Every actionable comment must receive an explicit disposition:

   - If the suggestion is valid, make the smallest correct fix on the branch for the lowest PR that owns the behavior, run the affected checks, and commit it there.
   - If the suggestion does not work, conflicts with another requirement, or would cause a regression, reply with the concrete technical reason instead of silently skipping it. Do not claim it was fixed.
   - If the comment is ambiguous, ask for clarification or post a clarifying reply rather than guessing.

   Replying to or resolving a GitHub thread is a remote write. Do it only when the user's request authorizes addressing comments. Resolve a thread only after its requested change or agreed disposition is complete; a reply alone does not automatically justify resolution.

3. When updates are authorized, after changing a non-top layer, run `gh stack rebase --upstack` before continuing upward. Resolve conflicts with the stack rebase workflow, rerun affected checks, and keep each fix on its owning layer. After all local fixes are complete, run one `gh stack push` to publish every rewritten active branch.

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
gh stack view
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
gh stack rebase       # first, only if history is not linear
gh stack modify       # stage operations and save with Ctrl+S
gh stack submit       # push branches and recreate/update the remote stack
```

The modify UI supports drop (`x`), fold down (`d`), fold up (`u`), insert below/above (`i`/`I`), rename (`r`), reorder (`Shift+Up`/`Shift+Down`), and undo (`z`). Do not mix reordering with structural operations in one session. On conflict, stage resolutions and run `gh stack modify --continue`; use `gh stack modify --abort` to restore the pre-modify snapshot.

Use `gh stack unstack` only with explicit confirmation. It removes local tracking and unlinks eligible PRs on GitHub but preserves their branches and PRs. Merged, merging, or queued PRs remain stacked. Use `--local` to remove only local tracking.

Use `gh stack merge [stack-or-pr-number]` only when explicitly asked to merge. Merging through a chosen PR includes every PR below it. Confirm that each selected PR is open, non-draft, approved, passing required checks, and linearly based before merging.

## Completion Check

Before reporting completion:

1. Run the requested tests and repository checks on the final branch state.
2. When a stack was used, run `gh stack view` from the stack-owning worktree and confirm branch order, PR association, and current position.
3. Run `git status --short` in the relevant existing worktrees and account for every remaining change without disturbing concurrent work.
4. State which branch was changed, whether descendants were rebased, and whether `push`, `submit`, `sync`, `link`, or `merge` changed GitHub.
5. Never claim the stack or PRs were updated remotely if only local commits were created.
6. When the task covered the full stack, include a per-PR comment and current-head CI result; do not summarize one passing PR as stack-wide success.

For current behavior and recovery details, consult GitHub's [creating](https://docs.github.com/en/pull-requests/how-tos/create-pull-requests/creating-stacked-pull-requests), [managing](https://docs.github.com/en/pull-requests/how-tos/create-pull-requests/managing-stacked-pull-requests), and [troubleshooting](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-stacked-pull-requests) guides.
