DRuntime: Runtime Library for the D Programming Language
========================================================

[![GitHub tag](https://img.shields.io/github/tag/dlang/druntime.svg?maxAge=86400)](https://github.com/dlang/druntime/releases)
[![Bugzilla Issues](https://img.shields.io/badge/issues-Bugzilla-green.svg)](https://issues.dlang.org/buglist.cgi?component=druntime&list_id=220148&product=D&resolution=---)
[![CircleCI](https://circleci.com/gh/dlang/druntime/tree/master.svg?style=svg)](https://circleci.com/gh/dlang/druntime/tree/master)
[![Buildkite](https://badge.buildkite.com/48ab4b9005c947aa3dbf0eeb4125391989c00c9545342b7b24.svg?branch=master)](https://buildkite.com/dlang/druntime)
[![Code coverage](https://img.shields.io/codecov/c/github/dlang/druntime.svg?maxAge=86400)](https://codecov.io/gh/dlang/druntime)
[![license](https://img.shields.io/github/license/dlang/druntime.svg)](https://github.com/dlang/druntime/blob/master/LICENSE.txt)

This is DRuntime. It is the low-level runtime library
backing the D programming language.

DRuntime is typically linked together with Phobos in a
release such that the compiler only has to link to a
single library to provide the user with the runtime and
the standard library.

Purpose
-------

DRuntime is meant to be an abstraction layer above the
compiler. Different compilers will likely have their
own versions of DRuntime. While the implementations
may differ, the interfaces should be the same.

Features
--------

The runtime library provides the following:

* The Object class, the root of the class hierarchy.
* Implementations of array operations.
* The associative array implementation.
* Type information and RTTI.
* Common threading and fiber infrastructure.
* Synchronization and coordination primitives.
* Exception handling and stack tracing.
* Garbage collection interface and implementation.
* Program startup and shutdown routines.
* Low-level math intrinsics and support code.
* Interfaces to standard C99 functions and types.
* Interfaces to operating system APIs.
* Atomic load/store and binary operations.
* CPU detection/identification for x86.
* System-independent time/duration functionality.
* D ABI demangling helpers.
* Low-level bit operations/intrinsics.
* Unit test, coverage, and trace support code.
* Low-level helpers for compiler-inserted calls.

Source structure
------

In the `src` directory, there are `core` and `rt` packages.

The `rt` package contains implementations for compiler-inserted calls.
You may not `import rt.xxx` outside of the `rt` package itself, since its source is not accessible once druntime is compiled;
it isn't included in the `druntime/import` that ships with compiler releases.
The compiler assumes these functions have a specific `extern(C)` signature, and expects them to be linked into the final binary.
See for example: [https://github.com/dlang/dmd/blob/master/src/dmd/backend/drtlsym.d](dmd/backend/drtlsym.d)

The `core` package is shipped with the compiler and has a stable API.
It contains implementations for D features, but also some D conversions of header files from external libraries:
- `core/stdc` - C standard library
- `core/stdcpp` - C++ standard library
- `core/sys` - operating system API

An exception to the public API is `core.internal`, which contains compiler hooks that are templates.
Many hooks from `rt` use `TypeInfo` class parameters, providing run-time type information, but they are being replaced by template functions, using static type information:
[Replace Runtime Hooks with Templates](https://github.com/dlang/projects/issues/25)

Since uninstantiated templates aren't compiled into the druntime binary, they can't be in `rt`.
Symbols from `core.internal` can be publically imported from other `core` modules, but are not supposed to be imported or otherwise referenced by end user modules.

Issues
------

To report a bug or look up known issues with the runtime library, please visit
the [bug tracker](http://issues.dlang.org/).

Licensing
---------

See the [LICENSE.txt](https://github.com/dlang/druntime/blob/master/LICENSE.txt) file for licensing information.

Building
--------

See the [wiki page](http://wiki.dlang.org/Building_DMD) for build instructions.
