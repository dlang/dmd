// REQUIRED_ARGS: -o-

/*
TEST_OUTPUT:
---
fail_compilation/fail14486.d(102): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(103): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(104): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(108): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(109): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(110): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(114): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(115): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(116): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(120): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(121): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(122): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(126): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(126): Error: `delete c0` is not `@safe` but is used in `@safe` function `test1a`
fail_compilation/fail14486.d(127): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(127): Error: `pure` function `fail14486.test1a` cannot call impure destructor `fail14486.C1a.~this`
fail_compilation/fail14486.d(127): Error: `@safe` function `fail14486.test1a` cannot call `@system` destructor `fail14486.C1a.~this`
fail_compilation/fail14486.d(101):        `fail14486.C1a.~this` is declared here
fail_compilation/fail14486.d(127): Error: `@nogc` function `fail14486.test1a` cannot call non-@nogc destructor `fail14486.C1a.~this`
fail_compilation/fail14486.d(128): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(128): Error: `pure` function `fail14486.test1a` cannot call impure destructor `fail14486.C2a.~this`
fail_compilation/fail14486.d(128): Error: `@safe` function `fail14486.test1a` cannot call `@system` destructor `fail14486.C2a.~this`
fail_compilation/fail14486.d(102):        `fail14486.C2a.~this` is declared here
fail_compilation/fail14486.d(128): Error: `@nogc` function `fail14486.test1a` cannot call non-@nogc destructor `fail14486.C2a.~this`
fail_compilation/fail14486.d(129): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(129): Error: `pure` function `fail14486.test1a` cannot call impure deallocator `fail14486.C3a.delete`
fail_compilation/fail14486.d(129): Error: `@safe` function `fail14486.test1a` cannot call `@system` deallocator `fail14486.C3a.delete`
fail_compilation/fail14486.d(103):        `fail14486.C3a.delete` is declared here
fail_compilation/fail14486.d(129): Error: `@nogc` function `fail14486.test1a` cannot call non-@nogc deallocator `fail14486.C3a.delete`
fail_compilation/fail14486.d(130): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(130): Error: `delete c4` is not `@safe` but is used in `@safe` function `test1a`
fail_compilation/fail14486.d(135): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(136): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(137): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(138): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(139): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(136): Error: destructor `fail14486.C1b.~this` is not `nothrow`
fail_compilation/fail14486.d(137): Error: destructor `fail14486.C2b.~this` is not `nothrow`
fail_compilation/fail14486.d(138): Error: deallocator `fail14486.C3b.delete` is not `nothrow`
fail_compilation/fail14486.d(133): Error: `nothrow` function `fail14486.test1b` may throw
fail_compilation/fail14486.d(144): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(144): Error: `delete s0` is not `@safe` but is used in `@safe` function `test2a`
fail_compilation/fail14486.d(145): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(145): Error: `pure` function `fail14486.test2a` cannot call impure destructor `fail14486.S1a.~this`
fail_compilation/fail14486.d(145): Error: `@safe` function `fail14486.test2a` cannot call `@system` destructor `fail14486.S1a.~this`
fail_compilation/fail14486.d(113):        `fail14486.S1a.~this` is declared here
fail_compilation/fail14486.d(145): Error: `@nogc` function `fail14486.test2a` cannot call non-@nogc destructor `fail14486.S1a.~this`
fail_compilation/fail14486.d(146): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(146): Error: `pure` function `fail14486.test2a` cannot call impure destructor `fail14486.S2a.~this`
fail_compilation/fail14486.d(146): Error: `@safe` function `fail14486.test2a` cannot call `@system` destructor `fail14486.S2a.~this`
fail_compilation/fail14486.d(114):        `fail14486.S2a.~this` is declared here
fail_compilation/fail14486.d(146): Error: `@nogc` function `fail14486.test2a` cannot call non-@nogc destructor `fail14486.S2a.~this`
fail_compilation/fail14486.d(147): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(147): Error: `pure` function `fail14486.test2a` cannot call impure deallocator `fail14486.S3a.delete`
fail_compilation/fail14486.d(147): Error: `@safe` function `fail14486.test2a` cannot call `@system` deallocator `fail14486.S3a.delete`
fail_compilation/fail14486.d(115):        `fail14486.S3a.delete` is declared here
fail_compilation/fail14486.d(147): Error: `@nogc` function `fail14486.test2a` cannot call non-@nogc deallocator `fail14486.S3a.delete`
fail_compilation/fail14486.d(148): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(153): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(154): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(155): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(156): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(157): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(154): Error: destructor `fail14486.S1b.~this` is not `nothrow`
fail_compilation/fail14486.d(155): Error: destructor `fail14486.S2b.~this` is not `nothrow`
fail_compilation/fail14486.d(156): Error: deallocator `fail14486.S3b.delete` is not `nothrow`
fail_compilation/fail14486.d(151): Error: `nothrow` function `fail14486.test2b` may throw
fail_compilation/fail14486.d(162): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(162): Error: `delete a0` is not `@safe` but is used in `@safe` function `test3a`
fail_compilation/fail14486.d(163): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(163): Error: `pure` function `fail14486.test3a` cannot call impure destructor `fail14486.S1a.~this`
fail_compilation/fail14486.d(163): Error: `@safe` function `fail14486.test3a` cannot call `@system` destructor `fail14486.S1a.~this`
fail_compilation/fail14486.d(113):        `fail14486.S1a.~this` is declared here
fail_compilation/fail14486.d(163): Error: `@nogc` function `fail14486.test3a` cannot call non-@nogc destructor `fail14486.S1a.~this`
fail_compilation/fail14486.d(164): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(164): Error: `pure` function `fail14486.test3a` cannot call impure destructor `fail14486.S2a.~this`
fail_compilation/fail14486.d(164): Error: `@safe` function `fail14486.test3a` cannot call `@system` destructor `fail14486.S2a.~this`
fail_compilation/fail14486.d(114):        `fail14486.S2a.~this` is declared here
fail_compilation/fail14486.d(164): Error: `@nogc` function `fail14486.test3a` cannot call non-@nogc destructor `fail14486.S2a.~this`
fail_compilation/fail14486.d(165): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(165): Error: `delete a3` is not `@safe` but is used in `@safe` function `test3a`
fail_compilation/fail14486.d(166): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(166): Error: `delete a4` is not `@safe` but is used in `@safe` function `test3a`
fail_compilation/fail14486.d(171): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(172): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(173): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(174): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(175): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(172): Error: destructor `fail14486.S1b.~this` is not `nothrow`
fail_compilation/fail14486.d(173): Error: destructor `fail14486.S2b.~this` is not `nothrow`
fail_compilation/fail14486.d(169): Error: `nothrow` function `fail14486.test3b` may throw
---
*/

class  C0a { }
class  C1a {                  ~this() {} }
class  C2a {                  ~this() {}  @nogc pure @safe delete(void* p) {} }
class  C3a { @nogc pure @safe ~this() {}                   delete(void* p) {} }
class  C4a { @nogc pure @safe ~this() {}  @nogc pure @safe delete(void* p) {} }

class  C0b { }
class  C1b {                  ~this() {} }
class  C2b {                  ~this() {}           nothrow delete(void* p) {} }
class  C3b {          nothrow ~this() {}                   delete(void* p) {} }
class  C4b {          nothrow ~this() {}           nothrow delete(void* p) {} }

struct S0a { }
struct S1a {                  ~this() {} }
struct S2a {                  ~this() {}  @nogc pure @safe delete(void* p) {} }
struct S3a { @nogc pure @safe ~this() {}                   delete(void* p) {} }
struct S4a { @nogc pure @safe ~this() {}  @nogc pure @safe delete(void* p) {} }

struct S0b { }
struct S1b {                  ~this() {} }
struct S2b {                  ~this() {}           nothrow delete(void* p) {} }
struct S3b {          nothrow ~this() {}                   delete(void* p) {} }
struct S4b {          nothrow ~this() {}           nothrow delete(void* p) {} }

void test1a() @nogc pure @safe
{
    C0a   c0;  delete c0;   // error
    C1a   c1;  delete c1;   // error
    C2a   c2;  delete c2;   // error
    C3a   c3;  delete c3;   // error
    C4a   c4;  delete c4;   // no error
}

void test1b() nothrow
{
    C0b   c0;  delete c0;    // no error
    C1b   c1;  delete c1;    // error
    C2b   c2;  delete c2;    // error
    C3b   c3;  delete c3;    // error
    C4b   c4;  delete c4;    // no error
}

void test2a() @nogc pure @safe
{
    S0a*  s0;  delete s0;   // error
    S1a*  s1;  delete s1;   // error
    S2a*  s2;  delete s2;   // error
    S3a*  s3;  delete s3;   // error
    S4a*  s4;  delete s4;   // no error
}

void test2b() nothrow
{
    S0b*  s0;  delete s0;    // no error
    S1b*  s1;  delete s1;    // error
    S2b*  s2;  delete s2;    // error
    S3b*  s3;  delete s3;    // error
    S4b*  s4;  delete s4;    // no error
}

void test3a() @nogc pure @safe
{
    S0a[] a0;  delete a0;   // error
    S1a[] a1;  delete a1;   // error
    S2a[] a2;  delete a2;   // error
    S3a[] a3;  delete a3;   // error
    S4a[] a4;  delete a4;   // error
}

void test3b() nothrow
{
    S0b[] a0;  delete a0;    // no error
    S1b[] a1;  delete a1;    // error
    S2b[] a2;  delete a2;    // error
    S3b[] a3;  delete a3;    // no error
    S4b[] a4;  delete a4;    // no error
}
