/*
TEST_OUTPUT:
---
fail_compilation/parseStc2.d(66): Error: conflicting attribute `const`
immutable const void f4() {}
          ^
fail_compilation/parseStc2.d(67): Error: conflicting attribute `@system`
@safe @system void f4() {}
       ^
fail_compilation/parseStc2.d(68): Error: conflicting attribute `@safe`
@trusted @safe void f4() {}
          ^
fail_compilation/parseStc2.d(69): Error: conflicting attribute `@trusted`
@system @trusted void f4() {}
         ^
fail_compilation/parseStc2.d(70): Error: conflicting attribute `__gshared`
shared __gshared f4() {}
       ^
fail_compilation/parseStc2.d(72): Error: redundant attribute `static`
static static void f1() {}
       ^
fail_compilation/parseStc2.d(73): Error: redundant attribute `pure`
pure nothrow pure void f2() {}
             ^
fail_compilation/parseStc2.d(74): Error: redundant attribute `@property`
@property extern(C) @property void f3() {}
                     ^
fail_compilation/parseStc2.d(75): Error: redundant attribute `@safe`
deprecated("") @safe @safe void f4() {}
                      ^
fail_compilation/parseStc2.d(78): Error: redundant linkage `extern (C)`
extern(C) extern(C) void f6() {}
                    ^
fail_compilation/parseStc2.d(79): Error: conflicting linkage `extern (C)` and `extern (C++)`
extern(C) extern(C++) void f7() {}
                      ^
fail_compilation/parseStc2.d(82): Error: redundant visibility attribute `public`
public public void f9() {}
       ^
fail_compilation/parseStc2.d(83): Error: conflicting visibility attribute `public` and `private`
public private void f10() {}
       ^
fail_compilation/parseStc2.d(85): Error: redundant alignment attribute `align`
align    align    void f11() {}
                  ^
fail_compilation/parseStc2.d(86): Error: redundant alignment attribute `align(1)`
align(1) align(1) void f12() {}
                  ^
fail_compilation/parseStc2.d(87): Error: redundant alignment attribute `align(1)`
align    align(1) void f13() {}
                  ^
fail_compilation/parseStc2.d(88): Error: redundant alignment attribute `align`
align(1) align    void f14() {}
                  ^
fail_compilation/parseStc2.d(89): Error: redundant alignment attribute `align(2)`
align(1) align(2) void f15() {}
                  ^
fail_compilation/parseStc2.d(91): Error: redundant linkage `extern (System)`
extern(System) extern(System) void f16() {}
                              ^
fail_compilation/parseStc2.d(92): Error: conflicting linkage `extern (System)` and `extern (C++)`
extern(System) extern(C++) void f17() {}
                           ^
---
*/
immutable const void f4() {}
@safe @system void f4() {}
@trusted @safe void f4() {}
@system @trusted void f4() {}
shared __gshared f4() {}

static static void f1() {}
pure nothrow pure void f2() {}
@property extern(C) @property void f3() {}
deprecated("") @safe @safe void f4() {}
@(1) @(1) void f5() {}  // OK

extern(C) extern(C) void f6() {}
extern(C) extern(C++) void f7() {}
extern(C++, foo) extern(C++, bar) void f8() {}  // OK

public public void f9() {}
public private void f10() {}

align    align    void f11() {}
align(1) align(1) void f12() {}
align    align(1) void f13() {}
align(1) align    void f14() {}
align(1) align(2) void f15() {}

extern(System) extern(System) void f16() {}
extern(System) extern(C++) void f17() {}
