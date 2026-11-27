# Contributing

How work is done in this repository. Rules for AI coding agents that go beyond this process are in [AGENTS.md](AGENTS.md).

This is the code of a master's thesis, developed by one person. Bug reports and ideas are welcome as [issues](https://github.com/Piotr-Gajewski/face-access-system/issues). Before writing a larger change, please open an issue first, because the scope is set by the research plan. Report vulnerabilities privately, as described in [SECURITY.md](SECURITY.md).

Everything here is in English: code, comments, commits, issues, pull requests and documentation.

## Workflow

One ticket = one branch = one pull request. Nothing is pushed directly to `main`.

1. **Pick a ticket** that is *Ready* on the [project board](https://github.com/users/Piotr-Gajewski/projects/2) and whose dependencies are closed. Move it to *In Progress*.
2. **Create a branch** linked to the issue: `gh issue develop <number> --checkout`.
3. **Make small commits** in the [Conventional Commits](#commits) format. Tests are written together with the code.
4. **Open a draft pull request** with `Closes #<number>` in the description. Say what changed, why, and how it was tested.
5. **Review:** the author reads every changed file, CI passes (once it exists) and all review threads are resolved.
6. **Squash merge:** only the repository owner merges. The branch is deleted automatically.

A pull request contains only what its ticket asks for. Anything else becomes a new issue.

## Local checks

[pre-commit](https://pre-commit.com/) runs checks on the staged files before every commit. If a check fails, the commit is not created. The hooks and their pinned versions are in [`.pre-commit-config.yaml`](.pre-commit-config.yaml).

Set it up once per clone:

```sh
uv tool install pre-commit   # once per machine
pre-commit install           # once per clone: run the hooks on every git commit
pre-commit run --all-files   # check the whole repository
```

The first run downloads the hook tools into `~/.cache/pre-commit` and takes a few minutes. Nothing is installed system-wide.

| Check | What it does |
|---|---|
| Whitespace, end of file | Removes trailing whitespace (not in Markdown, where it is a line break) and adds a final newline. These hooks fix the files and stop the commit: review the change, `git add` it and commit again. |
| YAML, JSON, TOML | Rejects files that do not parse. |
| Merge conflict markers | Rejects leftover `<<<<<<<` lines. |
| Case conflicts | Rejects file names that differ only in case, which break checkouts on Windows and macOS. |
| Shebangs | Rejects executable files without a `#!` line, and scripts with a `#!` line that are not executable. |
| Large files | Rejects files over 500 KB, such as datasets or model weights. |
| Private keys, gitleaks | Reject private keys, tokens, passwords and other secrets. |
| ShellCheck | Lints shell scripts. |
| nbstripout | Removes cell outputs from Jupyter notebooks, because they can embed images as base64. Like the whitespace hooks, it fixes the file and stops the commit. |
| Forbid media | Rejects images, audio and video outside `docs/assets/`, because photos and recordings of faces must never be committed. |
| Forbid arrays and models | Rejects array, pickle and model files (`.npy`, `.pkl`, `.h5`, `.onnx`, `.pt`, `.safetensors` and others) everywhere, because they can hold face embeddings. `.gitignore` alone is not enough: `git add -f` bypasses it. |

- Never skip the hooks with `git commit --no-verify`. CI runs the same checks, so a skipped failure comes back in the pull request.
- If gitleaks flags something that is not a secret, such as a documented example, add `gitleaks:allow` as a comment on that line and explain it in the pull request. Do not disable the hook.
- If a real secret was committed, revoke it first. Deleting it in a later commit does not remove it from the history.
- To allow media in another directory, extend the `exclude` pattern of the `forbid-media` hook and say why in the pull request. Generate test images in the test code instead of committing them.
- Update the hooks with `pre-commit autoupdate --freeze`, in a pull request of its own. Check each new `rev` against the release: for an annotated tag it pins the tag object instead of the commit, and it ignores tags that are not on the default branch.

## Commits

Commits and pull request titles follow [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): description`. The scope is optional.

| Type | Use for |
|---|---|
| `feat` | new functionality |
| `fix` | bug fix |
| `docs` | documentation only |
| `refactor` | code change without a change in behaviour |
| `perf` | performance improvement |
| `test` | tests only |
| `build` | build system, dependencies |
| `ci` | CI workflows |
| `chore` | other maintenance |
| `revert` | reverting an earlier commit |

- The pull request title and description become the commit on `main`, so write them for the project history.
- Commits must be signed; `main` rejects unsigned commits.

## Tickets

- Each ticket has one `area:` and one `type:` label and a size: **S** (up to one day), **M** (2–3 days) or **L** (about a week). An L ticket may wait in the backlog as material to split; only its smaller parts become *Ready*.
- A **spike** answers a question within a time box set in advance. Its result is a comment on the issue, not production code. When the time is up, it ends, even without a full answer.

### Definition of Ready

A ticket can enter a sprint when:

- [ ] the goal is clear without asking anyone
- [ ] the acceptance criteria are specific and can be checked
- [ ] the size is S or M (an L ticket has been split)
- [ ] dependencies and blockers are known
- [ ] it has an `area:` and a `type:` label

Acceptance criteria may be added, changed or removed during the work, but always with a comment on the issue that says why.

### Definition of Done

A ticket is done when:

- [ ] the acceptance criteria are met
- [ ] tests pass locally and in CI
- [ ] documentation or an ADR is updated, or neither is needed
- [ ] the change contains no secrets, biometric data, recordings, datasets or model weights with restricted licences
- [ ] the pull request is merged and the issue is closed
