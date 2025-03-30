<div align="center">

![dlang logo](https://dlang.org/images/dlogo.png)
# DMD
[![GitHub tag](https://img.shields.io/github/tag-date/dlang/dmd.svg?maxAge=86400&style=flat)](https://github.com/dlang/dmd/releases)
[![Code coverage](https://img.shields.io/codecov/c/github/dlang/dmd.svg?maxAge=86400&style=flat)](https://codecov.io/gh/dlang/dmd)
[![license](https://img.shields.io/github/license/dlang/dmd.svg?style=flat)](https://github.com/dlang/dmd/blob/master/LICENSE.txt)

[![Build status](https://img.shields.io/cirrus/github/dlang/dmd/master?label=Cirrus%20CI&logo=Cirrus%20CI)](https://cirrus-ci.com/github/dlang/dmd/master)
[![CircleCI](https://img.shields.io/circleci/project/github/dlang/dmd/master.svg?style=flat&label=circleci&logo=circleci)](https://circleci.com/gh/dlang/dmd/tree/master)
[![Build Status](https://dev.azure.com/dlanguage/dmd/_apis/build/status/Azure%20pipelines?branchName=master)](https://dev.azure.com/dlanguage/dmd/_build/latest?definitionId=1&branchName=master)
[![Buildkite](https://img.shields.io/buildkite/01239dde8424d69809d08769015bbdb9b90d05082e534d2f82/master.svg?style=flat&logo=dependabot&label=buildkite)](https://buildkite.com/dlang/dmd)
</div>

---
**DMD** is the reference compiler for the D programming language.

Releases, language specification and other resources can be found on the [homepage](https://dlang.org).
Please refer to the guidelines for [bug reports](CONTRIBUTING.md#reporting-bugs) to
report a problem or browse the list of open bugs.

### Overview

This repository is structured into the following directories.
Refer to their respective `README.md` for more in-depth information.

| Directory                            | Description                                       |
|--------------------------------------|---------------------------------------------------|
| [changelog](changelog)               | changelog entries for the upcoming release        |
| [ci](ci)                             | CI related scripts / utilities                    |
| [compiler](compiler)                 | root of all compiler (DMD/frontend) related code  |
| [compiler/src](compiler/src)         | source code, build system and build instructions  |
| [compiler/test](compiler/test)       | tests and testing infrastructure                  |
| [compiler/docs](compiler/docs)       | man pages and internal documentation              |
| [compiler/ini](compiler/ini)         | predefined `dmd.conf` files                       |
| [druntime](druntime)                 | root of all runtime related code                  |

With a D compiler and dub installed, dmd can be built with:

```
dub build dmd:compiler
```

For more information regarding compiling, installing, and
hacking on DMD, check the [contribution guide](CONTRIBUTING.md) and
visit the [D Wiki](https://wiki.dlang.org/DMD).

### Nightlies

Nightly builds based of the current DMD / Phobos `master` branch
can be found [here](https://github.com/dlang/dmd/releases/tag/nightly).
