/*
TEST_OUTPUT:
---
fail_compilation/parseStc3.d(69): Error: redundant attribute `pure`
pure      void f1() pure      {}
                    ^
fail_compilation/parseStc3.d(70): Error: redundant attribute `nothrow`
nothrow   void f2() nothrow   {}
                    ^
fail_compilation/parseStc3.d(71): Error: redundant attribute `@nogc`
@nogc     void f3() @nogc     {}
                     ^
fail_compilation/parseStc3.d(72): Error: redundant attribute `@property`
@property void f4() @property {}
                     ^
fail_compilation/parseStc3.d(75): Error: redundant attribute `@safe`
@safe     void f6() @safe    {}
                     ^
fail_compilation/parseStc3.d(76): Error: redundant attribute `@system`
@system   void f7() @system  {}
                     ^
fail_compilation/parseStc3.d(77): Error: redundant attribute `@trusted`
@trusted  void f8() @trusted {}
                     ^
fail_compilation/parseStc3.d(79): Error: conflicting attribute `@system`
@safe     void f9()  @system  {}
                      ^
fail_compilation/parseStc3.d(80): Error: conflicting attribute `@trusted`
@safe     void f10() @trusted {}
                      ^
fail_compilation/parseStc3.d(81): Error: conflicting attribute `@safe`
@system   void f11() @safe    {}
                      ^
fail_compilation/parseStc3.d(82): Error: conflicting attribute `@trusted`
@system   void f12() @trusted {}
                      ^
fail_compilation/parseStc3.d(83): Error: conflicting attribute `@safe`
@trusted  void f13() @safe    {}
                      ^
fail_compilation/parseStc3.d(84): Error: conflicting attribute `@system`
@trusted  void f14() @system  {}
                      ^
fail_compilation/parseStc3.d(86): Error: conflicting attribute `@system`
@safe @system  void f15() @trusted {}
       ^
fail_compilation/parseStc3.d(86): Error: conflicting attribute `@trusted`
@safe @system  void f15() @trusted {}
                           ^
fail_compilation/parseStc3.d(87): Error: conflicting attribute `@system`
@safe @system  void f16() @system  {}
       ^
fail_compilation/parseStc3.d(87): Error: redundant attribute `@system`
@safe @system  void f16() @system  {}
                           ^
fail_compilation/parseStc3.d(88): Error: conflicting attribute `@safe`
@system @safe  void f17() @system  {}
         ^
fail_compilation/parseStc3.d(88): Error: redundant attribute `@system`
@system @safe  void f17() @system  {}
                           ^
fail_compilation/parseStc3.d(89): Error: conflicting attribute `@safe`
@trusted @safe void f18() @trusted {}
          ^
fail_compilation/parseStc3.d(89): Error: redundant attribute `@trusted`
@trusted @safe void f18() @trusted {}
                           ^
---
*/
pure      void f1() pure      {}
nothrow   void f2() nothrow   {}
@nogc     void f3() @nogc     {}
@property void f4() @property {}
//ref     int  f5() ref       { static int g; return g; }

@safe     void f6() @safe    {}
@system   void f7() @system  {}
@trusted  void f8() @trusted {}

@safe     void f9()  @system  {}
@safe     void f10() @trusted {}
@system   void f11() @safe    {}
@system   void f12() @trusted {}
@trusted  void f13() @safe    {}
@trusted  void f14() @system  {}

@safe @system  void f15() @trusted {}
@safe @system  void f16() @system  {}
@system @safe  void f17() @system  {}
@trusted @safe void f18() @trusted {}
