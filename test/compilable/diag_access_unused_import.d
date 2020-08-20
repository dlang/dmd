// REQUIRED_ARGS: -wi -vcolumns -unittest -diagnose=access

/*
TEST_OUTPUT:
---
/home/per/Work/dmd/test/../../druntime/import/core/internal/atomic.d(1107,25): Warning: unmodified public variable `index` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../druntime/import/core/internal/atomic.d(1097,22): Warning: unmodified public variable `isQ` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../druntime/import/core/internal/atomic.d(1093,9): Warning: unused public variable `i` of foreach, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../druntime/import/core/internal/atomic.d(1093,9): Warning: unmodified public variable `i` of foreach should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../phobos/std/stdio.d(4839,25): Warning: unused public variable `impl` of function, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../phobos/std/stdio.d(4839,25): Warning: unmodified public variable `impl` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../phobos/std/stdio.d(4840,20): Warning: unused public variable `result` of function, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../phobos/std/stdio.d(4840,20): Warning: unmodified public variable `result` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../phobos/std/stdio.d(4839,25): Warning: unused public variable `impl` of function, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../phobos/std/stdio.d(4839,25): Warning: unmodified public variable `impl` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../phobos/std/stdio.d(4840,20): Warning: unused public variable `result` of function, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../phobos/std/stdio.d(4840,20): Warning: unmodified public variable `result` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../phobos/std/stdio.d(4839,25): Warning: unused public variable `impl` of function, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../phobos/std/stdio.d(4839,25): Warning: unmodified public variable `impl` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../phobos/std/stdio.d(4840,20): Warning: unused public variable `result` of function, rename to `_` or prepend `_` to name to silence
/home/per/Work/dmd/test/../../phobos/std/stdio.d(4840,20): Warning: unmodified public variable `result` of function should be declared `const` or `immutable`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_import.d(37,8): Warning: unused module `iteration` of private import `std`
compilable/diag_access_unused_import.d(42,19): Warning: unused private aliased import `ioUnused`
compilable/diag_access_unused_import.d(44,9): Warning: unused private alias `wr` of module `diag_access_unused_import`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_import.d(48,8): Warning: unused private imported alias `writeln`
compilable/diag_access_unused_import.d(50,8): Warning: unused private imported alias `map2`
compilable/diag_access_unused_import.d(51,8): Warning: unused private imported alias `filter`
compilable/diag_access_unused_import.d(54,9): Warning: unused private alias `ET` of module `diag_access_unused_import`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_import.d(56,8): Warning: unused private imported alias `isStaticArray`
compilable/diag_access_unused_import.d(59,14): Warning: unused private manifest constant `f` of module `diag_access_unused_import`, rename to `_` or prepend `_` to name to silence
compilable/diag_access_unused_import.d(60,14): Warning: unused private manifest constant `g` of module `diag_access_unused_import`, rename to `_` or prepend `_` to name to silence
---
*/

public import std.algorithm.searching; // potentially used by other module

import std.algorithm.iteration; // warn, unused

import std.algorithm.mutation;  // used
alias cp = copy;                // potentially used by other module

import ioUnused = std.stdio;    // warn, unused
import ioUsed = std.stdio;      // used
private alias wr = ioUsed.write; // warn, unused

public import std.stdio : write; // may be used elsewhere

import std.stdio : writeln;     // warn, unused

import std.algorithm.iteration : map2 = map; // warn, unused
import std.algorithm.iteration : filter;     // warn, unused

import std.range.primitives;
private alias ET = ElementType; // warn, unused

import std.traits : isDynamicArray, isStaticArray; // warn, unused

enum e = isDynamicArray!(int);
private enum f = e;                    // warn, unused
private enum g = isDynamicArray!(int); // warn, unused
