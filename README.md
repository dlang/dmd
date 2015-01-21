DRuntime: Runtime Library for the D Programming Language
========================================================

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

Issues
------

To report a bug or look up known issues with the runtime library, please visit
the [bug tracker](http://issues.dlang.org/).

Licensing
---------

See the LICENSE file for licensing information.

Building
--------

See the [wiki page](http://wiki.dlang.org/Building_DMD) for build instructions.
