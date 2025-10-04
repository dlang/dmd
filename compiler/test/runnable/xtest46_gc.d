/*
REQUIRED_ARGS: -lowmem -Jrunnable -preview=rvaluerefparam
EXTRA_FILES: xtest46.d
TEST_OUTPUT:
---
Boo!double
Boo!int
true
int
!! immutable(int)[]
int(int i, long j = 7L)
long
C10390(C10390(<recursion>))
AliasSeq!(height)
AliasSeq!(get, get)
AliasSeq!(clear)
AliasSeq!(draw, draw)
const(int)
string[]
double[]
double[]
{}
AliasSeq!("m")
true
TFunction1: extern (C) void function()
runnable/xtest46_gc.d-mixin-53(6575): Deprecation: Using variable `item` declared in a loop from a closure is deprecated
    foreach (ref item; items)
    ^
runnable/xtest46_gc.d-mixin-53(6581):        Variable `item` used in possibly escaping function `__lambda_L6581_C23`
        takeADelegate({ auto x = &item; });
                      ^
runnable/xtest46_gc.d-mixin-53(6584): Deprecation: Using variable `val` declared in a loop from a closure is deprecated
    foreach(ref val; [3])
    ^
runnable/xtest46_gc.d-mixin-53(6586):        Variable `val` used in possibly escaping function `__lambda_L6586_C19`
        auto dg = { int j = val; };
                  ^
runnable/xtest46_gc.d-mixin-53(6606): Deprecation: Using variable `i` declared in a loop from a closure is deprecated
    foreach (i, j; [0])
    ^
runnable/xtest46_gc.d-mixin-53(6608):        Variable `i` used in possibly escaping function `__lambda_L6608_C14`
        call({
             ^
runnable/xtest46_gc.d-mixin-53(6613): Deprecation: Using variable `n` declared in a loop from a closure is deprecated
    foreach (n; 0..1)
    ^
runnable/xtest46_gc.d-mixin-53(6615):        Variable `n` used in possibly escaping function `__lambda_L6615_C14`
        call({
             ^
---
*/

mixin(import("xtest46.d"));
