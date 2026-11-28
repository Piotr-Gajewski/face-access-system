# Scripts

## github-setup.sh

Describes the GitHub configuration of this repository as code: repository settings, GitHub Actions permissions, the `main` ruleset with its required CI checks, labels, milestones and the [project board](https://github.com/users/Piotr-Gajewski/projects/2). The target state is at the top of the script; change it there, in a pull request, not in the GitHub interface.

| Command | Effect |
|---|---|
| `bash scripts/github-setup.sh --check` | Verifies the configuration. Changes nothing, including the `gh` token. |
| `bash scripts/github-setup.sh` | **Changes live settings** to the target state, then verifies them. Can be run many times. |

Any other argument is rejected before GitHub is called, so a mistyped `--check` cannot start the mode that changes settings.

| Exit code | Meaning |
|---|---|
| 0 | No errors. Items marked ● still need a look by hand. |
| 1 | Something differs from the target state (✘), or the run could not start or finish. |
| 2 | Unknown or too many arguments. |

### Requirements

- Bash 4.4 or newer and GNU coreutils, as in Ubuntu
- [`gh`](https://cli.github.com) logged in as the repository owner; tested with 2.105.0 (`gh auth status` must support `--no-refresh`)
- `jq`; tested with 1.7
- To change the script: `pre-commit run shellcheck --all-files` must pass. pre-commit brings its own pinned ShellCheck ([CONTRIBUTING.md](../CONTRIBUTING.md#local-checks)).

### Token scopes

| Scope | Used for |
|---|---|
| `repo` | settings, ruleset, labels, milestones, issues |
| `project` | reading and changing the board |

`gh auth login` already grants `repo`, together with `read:org` and `gist`, which `gh` always requires. Add the other one with:

```
gh auth refresh -h github.com -s project
```

Without `project`, `--check` stops with an error that shows this command, and the mode that changes settings runs it (it opens a browser).

### Settings to make by hand

The API cannot set these. The script checks what it can read and marks the rest with ●.

| Where on the board | Setting | Checked by the script |
|---|---|---|
| ⋯ → Workflows | On: *Auto-add to project* (filter `is:issue is:open`), *Item added to project*, *Pull request linked to issue*, *Item closed*, *Item reopened*, *Pull request merged* | on/off only |
| ⋯ → Workflows | *Item added to project* sets Status to Backlog; *Pull request linked to issue* to In review; *Pull request merged* and *Item closed* to Done | no |
| ⋯ → Workflows | *Auto-archive items* off | no |
| View *Planning* | Group by Sprint | yes |
| View *Roadmap* | Group by Milestone | yes |
| View *Roadmap* | Date fields: Sprint start and end | no |
| Fields *Status* and *Size* | Options and their order, if they ever change | yes |

The script creates *Status* and *Size* when they are missing, but never overwrites their options. The API replaces all options and gives them new IDs: every item loses its value, and the workflows that set *Status* are switched off. Editing the options in the UI keeps their IDs.

If the board cannot be read during a run, the script stops instead of going on, because missing data would look like missing fields and they would be created again.

### Board workflows

Changing the board can switch its workflows off without a message. The script reads the state of every workflow before the first change and again at the end, and reports each one that was switched off or disappeared. Turn it on again by hand.

### Required CI checks

`REQUIRED_CHECKS` lists the jobs that must pass before a pull request can be merged. It holds only `ci`, the job that summarises all others ([CONTRIBUTING.md](../CONTRIBUTING.md#continuous-integration)), so a new CI job needs no change here. Each check must be reported by the GitHub Actions app (`CHECKS_APP_ID`), so no other token can mark it as passed.

The script writes the checks into a new ruleset and into the existing one. In the existing ruleset it replaces only the `required_status_checks` rule and sends all other rules back unchanged, so the result does not depend on whether the API merges the list of rules or replaces it.

Add a job to `REQUIRED_CHECKS` only after it has run at least once in a pull request. A required check that has never reported blocks every pull request.
