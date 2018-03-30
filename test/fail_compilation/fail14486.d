// REQUIRED_ARGS: -o-

/*
TEST_OUTPUT:
---
fail_compilation/fail14486.d(23): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(24): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(25): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(29): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(30): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(31): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(35): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(36): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(37): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(41): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(42): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
fail_compilation/fail14486.d(43): Deprecation: class deallocators have been deprecated, consider moving the deallocation strategy outside of the class
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

/*
TEST_OUTPUT:
---
fail_compilation/fail14486.d(68): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(68): Error: `delete c0` is not `@safe` but is used in `@safe` function `test1a`
fail_compilation/fail14486.d(69): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(69): Error: `pure` function `fail14486.test1a` cannot call impure destructor `fail14486.C1a.~this`
fail_compilation/fail14486.d(69): Error: `@safe` function `fail14486.test1a` cannot call `@system` destructor `fail14486.C1a.~this`
fail_compilation/fail14486.d(69): Error: `@nogc` function `fail14486.test1a` cannot call non-@nogc destructor `fail14486.C1a.~this`
fail_compilation/fail14486.d(70): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(70): Error: `pure` function `fail14486.test1a` cannot call impure destructor `fail14486.C2a.~this`
fail_compilation/fail14486.d(70): Error: `@safe` function `fail14486.test1a` cannot call `@system` destructor `fail14486.C2a.~this`
fail_compilation/fail14486.d(70): Error: `@nogc` function `fail14486.test1a` cannot call non-@nogc destructor `fail14486.C2a.~this`
fail_compilation/fail14486.d(71): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(71): Error: `pure` function `fail14486.test1a` cannot call impure deallocator `fail14486.C3a.delete`
fail_compilation/fail14486.d(71): Error: `@safe` function `fail14486.test1a` cannot call `@system` deallocator `fail14486.C3a.delete`
fail_compilation/fail14486.d(71): Error: `@nogc` function `fail14486.test1a` cannot call non-@nogc deallocator `fail14486.C3a.delete`
fail_compilation/fail14486.d(72): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(72): Error: `delete c4` is not `@safe` but is used in `@safe` function `test1a`
---
*/
void test1a() @nogc pure @safe
{
    C0a   c0;  delete c0;   // error
    C1a   c1;  delete c1;   // error
    C2a   c2;  delete c2;   // error
    C3a   c3;  delete c3;   // error
    C4a   c4;  delete c4;   // no error
}

/*
TEST_OUTPUT:
---
fail_compilation/fail14486.d(91): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(92): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(93): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(94): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(95): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(92): Error: destructor `fail14486.C1b.~this` is not `nothrow`
fail_compilation/fail14486.d(93): Error: destructor `fail14486.C2b.~this` is not `nothrow`
fail_compilation/fail14486.d(94): Error: deallocator `fail14486.C3b.delete` is not `nothrow`
fail_compilation/fail14486.d(89): Error: `nothrow` function `fail14486.test1b` may throw
---
*/
void test1b() nothrow
{
    C0b   c0;  delete c0;    // no error
    C1b   c1;  delete c1;    // error
    C2b   c2;  delete c2;    // error
    C3b   c3;  delete c3;    // error
    C4b   c4;  delete c4;    // no error
}

/*
TEST_OUTPUT:
---
fail_compilation/fail14486.d(120): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(120): Error: `delete s0` is not `@safe` but is used in `@safe` function `test2a`
fail_compilation/fail14486.d(121): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(121): Error: `pure` function `fail14486.test2a` cannot call impure destructor `fail14486.S1a.~this`
fail_compilation/fail14486.d(121): Error: `@safe` function `fail14486.test2a` cannot call `@system` destructor `fail14486.S1a.~this`
fail_compilation/fail14486.d(121): Error: `@nogc` function `fail14486.test2a` cannot call non-@nogc destructor `fail14486.S1a.~this`
fail_compilation/fail14486.d(122): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(122): Error: `pure` function `fail14486.test2a` cannot call impure destructor `fail14486.S2a.~this`
fail_compilation/fail14486.d(122): Error: `@safe` function `fail14486.test2a` cannot call `@system` destructor `fail14486.S2a.~this`
fail_compilation/fail14486.d(122): Error: `@nogc` function `fail14486.test2a` cannot call non-@nogc destructor `fail14486.S2a.~this`
fail_compilation/fail14486.d(123): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(123): Error: `pure` function `fail14486.test2a` cannot call impure deallocator `fail14486.S3a.delete`
fail_compilation/fail14486.d(123): Error: `@safe` function `fail14486.test2a` cannot call `@system` deallocator `fail14486.S3a.delete`
fail_compilation/fail14486.d(123): Error: `@nogc` function `fail14486.test2a` cannot call non-@nogc deallocator `fail14486.S3a.delete`
fail_compilation/fail14486.d(124): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
---
*/
void test2a() @nogc pure @safe
{
    S0a*  s0;  delete s0;   // error
    S1a*  s1;  delete s1;   // error
    S2a*  s2;  delete s2;   // error
    S3a*  s3;  delete s3;   // error
    S4a*  s4;  delete s4;   // no error
}

/*
TEST_OUTPUT:
---
fail_compilation/fail14486.d(143): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(144): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(145): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(146): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(147): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(144): Error: destructor `fail14486.S1b.~this` is not `nothrow`
fail_compilation/fail14486.d(145): Error: destructor `fail14486.S2b.~this` is not `nothrow`
fail_compilation/fail14486.d(146): Error: deallocator `fail14486.S3b.delete` is not `nothrow`
fail_compilation/fail14486.d(141): Error: `nothrow` function `fail14486.test2b` may throw
---
*/
void test2b() nothrow
{
    S0b*  s0;  delete s0;    // no error
    S1b*  s1;  delete s1;    // error
    S2b*  s2;  delete s2;    // error
    S3b*  s3;  delete s3;    // error
    S4b*  s4;  delete s4;    // no error
}

/*
TEST_OUTPUT:
---
fail_compilation/fail14486.d(171): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(171): Error: `delete a0` is not `@safe` but is used in `@safe` function `test3a`
fail_compilation/fail14486.d(172): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(172): Error: `pure` function `fail14486.test3a` cannot call impure destructor `fail14486.S1a.~this`
fail_compilation/fail14486.d(172): Error: `@safe` function `fail14486.test3a` cannot call `@system` destructor `fail14486.S1a.~this`
fail_compilation/fail14486.d(172): Error: `@nogc` function `fail14486.test3a` cannot call non-@nogc destructor `fail14486.S1a.~this`
fail_compilation/fail14486.d(173): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(173): Error: `pure` function `fail14486.test3a` cannot call impure destructor `fail14486.S2a.~this`
fail_compilation/fail14486.d(173): Error: `@safe` function `fail14486.test3a` cannot call `@system` destructor `fail14486.S2a.~this`
fail_compilation/fail14486.d(173): Error: `@nogc` function `fail14486.test3a` cannot call non-@nogc destructor `fail14486.S2a.~this`
fail_compilation/fail14486.d(174): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(174): Error: `delete a3` is not `@safe` but is used in `@safe` function `test3a`
fail_compilation/fail14486.d(175): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(175): Error: `delete a4` is not `@safe` but is used in `@safe` function `test3a`
---
*/
void test3a() @nogc pure @safe
{
    S0a[] a0;  delete a0;   // error
    S1a[] a1;  delete a1;   // error
    S2a[] a2;  delete a2;   // error
    S3a[] a3;  delete a3;   // error
    S4a[] a4;  delete a4;   // error
}

/*
TEST_OUTPUT:
---
fail_compilation/fail14486.d(193): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(194): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(195): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(196): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(197): Deprecation: The `delete` keyword has been deprecated.  Use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead.
fail_compilation/fail14486.d(194): Error: destructor `fail14486.S1b.~this` is not `nothrow`
fail_compilation/fail14486.d(195): Error: destructor `fail14486.S2b.~this` is not `nothrow`
fail_compilation/fail14486.d(191): Error: `nothrow` function `fail14486.test3b` may throw
---
*/
void test3b() nothrow
{
    S0b[] a0;  delete a0;    // no error
    S1b[] a1;  delete a1;    // error
    S2b[] a2;  delete a2;    // error
    S3b[] a3;  delete a3;    // no error
    S4b[] a4;  delete a4;    // no error
}
