/*
TEST_OUTPUT:
---
fail_compilation/class_interface_checks.d(22): Error: class `class_interface_checks.B` interface function `int f()` is not implemented
fail_compilation/class_interface_checks.d(26): Error: class `class_interface_checks.D` interface function `int f()` is not implemented
fail_compilation/class_interface_checks.d(31): Error: class `class_interface_checks.F` interface function `int f()` is not implemented
fail_compilation/class_interface_checks.d(31): Error: class `class_interface_checks.F` interface function `int g()` is not implemented
fail_compilation/class_interface_checks.d(37): Error: class `class_interface_checks.K` interface function `int h()` is not implemented
---
*/


// https://github.com/dlang/dmd/issues/19807
// Unimplemented interface methods inherited through an abstract base class
// should be detected, instead of compiling and segfaulting at runtime.

interface I { int f(); }

abstract class A : I {}

// B is concrete but doesn't implement I.f, inherited via abstract A
class B : A {}

// Unimplemented through a deeper chain of abstract classes
abstract class C : A {}
class D : C {}

// Interface that extends another interface, both methods unimplemented
interface J : I { int g(); }
abstract class E : J {}
class F : E {}

// A base class method that does not itself implement the interface cannot
// satisfy a directly-declared interface
class G { int h() { return 1; } }
interface H { int h(); }
class K : G, H {}

// Valid cases:

// The abstract base class itself implements the interface method
abstract class J1 : I { int f() { return 1; } }
class J2 : J1 {}

// Implementation provided in the middle of a chain of abstract classes
abstract class L : I {}
abstract class M : L { int f() { return 2; } }
class N : M {}

// Concrete leaf provides the implementation
abstract class O : I {}
class P : O { int f() { return 3; } }
