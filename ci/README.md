# Continuous Integration

When a Pull Request (PR) is opened, several automated checks are performed to ensure the new compiler still builds, passes tests, and does not break external projects.
Since DMD runs on many platforms and lots of D infrastructure depends on it, they are spread over many CI services.

## Troubleshooting failed checks
When your PR fails checks, click on the "Details" link next to it to see what the error is.

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

There are currently 49 checks.

### Azure pipelines

**Config**: [azure-pipelines.yml](https://github.com/dlang/dmd/blob/master/azure-pipelines.yml)

**Checks**:
- Azure pipelines
- Azure pipelines (Windows_Coverage x64)
- Azure pipelines (Windows_DMD_bootstrap x64)
- Azure pipelines (Windows_DMD_latest x64)
- Azure pipelines (Windows_DMD_latest x86-OMF)
- Azure pipelines (Windows_VisualD_LDC x64_Debug)
- Azure pipelines (Windows_VisualD_LDC x86-mscoff)
- Azure pipelines (Windows_VisualD_LDC x86-mscoff_MinGW)

Azure pipelines run on Windows platforms, and build DMD, Phobos and Druntime, and run their unittests.
Windows has three binary formats: 32-bit OMF (deprecated), 32-bit COFF, and 64-bit COFF.

### DAutoTest

**Config**: [CyberShadow/DAutoTest](https://github.com/CyberShadow/DAutoTest)

**Checks**:
- CyberShadow/DAutoTest — Documentation

DMD includes a documentation generator, which is also used to build [the dlang.org website](https://github.com/dlang/dlang.org/).
DAutoTest does the following:

* Builds the documentation by invoking the dlang.org makefile.

* This necessarily also builds the compiler, runtime, standard library, and fetches some dependencies.

* Saves the resulting HTML files and makes them available for preview.

* Allows looking at the differences in generated HTML between the base branch and the PR branch.

If your [changelog entry](https://github.com/dlang/dmd/tree/master/changelog) has incorrect DDoc syntax, it will be caught by this check.

### auto-tester

**Config**: private

**Checks**:
- auto-tester

The auto tester tests DMD on various Posix platforms.

### C++ interop tests

**Config**: [azure-pipelines.yml](https://github.com/dlang/dmd/blob/master/.github/workflows/runnable_cxx.yml)

**Checks**:
- C++ interop tests / Run (macOS-10.15, clang-13.0.0)
- C++ interop tests / Run (macOS-10.15, clang-12.0.0)
- C++ interop tests / Run (macOS-10.15, clang-11.0.0)
- C++ interop tests / Run (macOS-10.15, clang-10.0.0)
- C++ interop tests / Run (macOS-10.15, clang-9.0.0)
- C++ interop tests / Run (macOS-10.15, clang-8.0.0)
- C++ interop tests / Run (ubuntu-18.04, clang-10.0.0)
- C++ interop tests / Run (ubuntu-18.04, clang-9.0.0)
- C++ interop tests / Run (ubuntu-18.04, clang-8.0.0)
- C++ interop tests / Run (ubuntu-18.04, g++-9)
- C++ interop tests / Run (ubuntu-18.04, g++-8)
- C++ interop tests / Run (ubuntu-18.04, g++-7)
- C++ interop tests / Run (ubuntu-18.04, g++-6)
- C++ interop tests / Run (ubuntu-18.04, g++-5)
- C++ interop tests / Run (ubuntu-20.04, clang-13.0.0)
- C++ interop tests / Run (ubuntu-20.04, clang-12.0.0)
- C++ interop tests / Run (ubuntu-20.04, clang-11.0.0)
- C++ interop tests / Run (ubuntu-20.04, g++-11)
- C++ interop tests / Run (ubuntu-20.04, g++-10)
- C++ interop tests / Run (ubuntu-20.04, g++-9)

Github action to test for C++ interoperability

Most tests in the test-suite run on the CI when it comes to cross-platform testing.
However, the dlang auto-tester uses a somewhat old host C/C++ compiler.
This is good for testing compatibility with e.g. LTS distributions, but becomes problematic when we want to test more cutting-edge features, such as newer C++ standards (C++17, C++20, etc...).
This is the reason why we have this action: we have full control over the toolchain, and it's cross platform.

### Codecov

**Config**: [.codecov.yml](https://github.com/dlang/dmd/blob/master/.codecov.yml)

**Checks**:
- codecov/patch

Codecov checks code coverage, meaning that the lines of code you modified are executed at least once in the test suite.
While there are currently no hard constraints on coverage for a Pull Request to pass the check, it does emit warnings for modified lines that are not covered into the "Files Changed" tab.
These should be taken seriously, since untested code is likely to introduce bugs, and can easily be accidentally broken by future changes.

### CirrusCI

**Config**: [.cirrus.yml](https://github.com/dlang/dmd/blob/master/.cirrus.yml)

**Checks**:
- FreeBSD 11.4 x64, DMD (bootstrap)
- FreeBSD 12.2 x64, DMD (coverage)
- FreeBSD 12.2 x64, DMD (latest)
- Ubuntu 18.04 x64, DMD (bootstrap)
- Ubuntu 18.04 x64, DMD (latest)
- Ubuntu 18.04 x64, GDC
- Ubuntu 18.04 x64, LDC
- Ubuntu 18.04 x86, DMD (bootstrap)
- Ubuntu 18.04 x86, DMD (coverage)
- Ubuntu 18.04 x86, DMD (latest)
- macOS 10.15 x64, DMD (bootstrap)
- macOS 11.x x64, DMD (coverage)
- macOS 11.x x64, DMD (latest)
- macOS 12.x x64, DMD (coverage)
- macOS 12.x x64, DMD (latest)

Cirrus tests DMD on Posix platforms.

Since DMD is written in D, a "Host D Compiler" is needed to compile it.
Various host compilers are tested, such as GDC, LDC, the latest DMD, and an older verison of DMD (bootstrap).
Note that the GDC and LDC targets do not run any tests, the simply build the latest version of the dmd frontend.

Sometimes the macOS VMs get corrupted.
When that happens, you can file an issue on Cirrus' issue tracker, [like this one](https://github.com/cirruslabs/macos-image-templates/issues/43).

### pre-commit

**Config**: [.pre-commit-config.yaml](https://github.com/dlang/dmd/blob/master/.pre-commit-config.yaml)

**Checks**:
- pre_commit

pre-commit checks for redundant white space, such as trailing whitespace and newlines.

If you want to automatically make your changes comply with the check, you can download `pre-commit` via your package manager, or with  `pip`.
See https://pre-commit.com/.

Run `pre-commit install` inside the root of the repository,
This will add a hook into `.git/hooks/pre-commit`.
Every time you do a commit it will do pre-commit checks.

If you already have a custom `pre-commit` hook, you can modify the bash script to run `pre-commit` manually with `pre-commit run`.
pre-commit is designed to run only on diffed files so it will run pretty quickly, but if you want to for it to run on all files you can do `pre-commit run --all-files`.

### buildkite

**Config:** [ci/buildkite](https://github.com/dlang/ci/tree/master/buildkite)

**Checks**:
- buildkite

Buildkite tests that the compiler is still able to compile and pass the test suite of several popular D projects.

The configuration file is found in a separate repository, since it is shared by druntime and Phobos.

### CircleCI

**Config**: [.circleci/config.yml](https://github.com/dlang/dmd/blob/master/.circleci/config.yml)

**Checks**:
- ci/circleci: build

CircleCI tests DMD on Ubuntu 18.04.

It also tests that the automatically generated C++ header, frontend.h, is updated.
This is important because other compilers sharing the front-end (LDC and GDC) rely on DMD's header files to interface with it.
When a PR modifies an `extern(C++)` function, the corresponding signature in a .h file should be updated as well, see [cxx-headers-test](https://github.com/dlang/dmd/tree/master/src#cxx-headers-test).
