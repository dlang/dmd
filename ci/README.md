# Continuous Integration

When a Pull Request (PR) is opened, several automated checks are performed to ensure the new compiler still builds, passes tests, and does not break external projects.

## Troubleshooting failed checks
When your PR fails checks, click on the "Details" link next to it to see what the error is.

Most log files are the output of `make`, which prints the commands it invokes followed by the output of that command.
Execution stops after a failed command, so errors can usually be found near the end of the log.
Because of multi-threaded builds, they don't need to be at the very end however.
You can Ctrl+F search for a triple asterisk `***` to easily find failed commands.

Errors caused by the changes you made should be addressed by pushing new commits to your branch.

When it looks like the error is unrelated to your PR's changes, try rebasing your branch.
First, ensure that you have a 'remote' pointing to both dlang/dmd and your own fork of dmd, for example:
```
git remote -v
origin  git@github.com:your-github-name/dmd.git (fetch)
origin  git@github.com:your-github-name/dmd.git (push)
upstream        git@github.com:dlang/dmd.git (fetch)
upstream        git@github.com:dlang/dmd.git (push)
```

If you don't have an `upstream` remote, you can add it with:
```
git remote add upstream git@github.com:dlang/dmd.git
```

Then, pull the latest changes from the branch that your PR is targeting (`master` or `stable`) and rebase your branch.
```
git checkout master
git pull --ff-only upstream master
git checkout your-branch
git rebase master
git push --force origin your-branch
```

Or more directly, without pulling in the changes locally:
```
git checkout your-branch
git fetch
git rebase upstream/master
git push --force origin your-branch
```

If your branch is already based on the latest commit, you get this message:
```
Current branch your-branch is up to date.
```

If you still want to re-run the checks, you can amend your last commit and force push:
```
git commit --amend
git push --force origin your-branch
```

When an unrelated failure persists, ask a maintainer for help.

## Overview of checks

All checks except buildkite and DAutoTest run on GitHub Actions, configured in [.github/workflows](../.github/workflows).
Each job's steps are plain `make` and `run.d` commands, so you can run the same command locally to reproduce a failure.

| Check | Config | What it does |
|---|---|---|
| `Lint` | [lint.yml](../.github/workflows/lint.yml), [.pre-commit-config.yaml](../.pre-commit-config.yaml) | Trailing whitespace, line endings, workflow syntax, changelog file names. |
| `Main / <OS>, <host compiler>` | [main.yml](../.github/workflows/main.yml) | Builds dmd with the named host compiler, then runs the dmd unittests, the compiler test suite, the druntime and Phobos unittests, and a self-compile. *bootstrap* jobs use the oldest supported host compiler. The *Visual D* jobs build dmd with the Visual Studio project. |
| `C++ interop (<C++ compiler>)` | [cxx.yml](../.github/workflows/cxx.yml) | `runnable_cxx` tests, druntime's `core.stdcpp` tests and the C++ header checks against old and new GCC and Clang. MSVC and Apple Clang are tested by the main jobs. |
| `perf` | [perf.yml](../.github/workflows/perf.yml) | Compares compile time, memory and binary size with the target branch, see [PERF.md](../.github/PERF.md). |
| `buildkite/dmd` | [dlang/ci](https://github.com/dlang/ci/tree/master/buildkite) | Builds and tests popular D projects from the dub registry with the new compiler. |
| `CyberShadow/DAutoTest` | [DAutoTest](https://github.com/CyberShadow/DAutoTest) | Builds the dlang.org documentation (catches bad DDoc in changelog entries) and shows a diff of the generated HTML. |

On pushes to master and stable, [bootstrap.yml](../.github/workflows/bootstrap.yml) also checks that dmd builds with every host compiler release since 2.076.

### pre-commit

To fix lint failures automatically, install [`pre-commit`](https://pre-commit.com/) and run `pre-commit install` in the repository root.
This runs the checks on every commit. To check all files, run `pre-commit run --all-files`.
