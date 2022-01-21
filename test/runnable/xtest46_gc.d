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
runnable/xtest46_gc.d-mixin-40(2981): Deprecation: alias this for classes is deprecated
runnable/xtest46_gc.d-mixin-40(3013): Deprecation: alias this for classes is deprecated
int(int i, long j = 7L)
long
C10390(C10390(<recursion>))
tuple(height)
tuple(get, get)
tuple(clear)
tuple(draw, draw)
runnable/xtest46_gc.d-mixin-40(188): Deprecation: `opDot` is deprecated. Use `alias this`
runnable/xtest46_gc.d-mixin-40(190): Deprecation: `opDot` is deprecated. Use `alias this`
runnable/xtest46_gc.d-mixin-40(191): Deprecation: `opDot` is deprecated. Use `alias this`
runnable/xtest46_gc.d-mixin-40(193): Deprecation: `opDot` is deprecated. Use `alias this`
runnable/xtest46_gc.d-mixin-40(220): Deprecation: `opDot` is deprecated. Use `alias this`
runnable/xtest46_gc.d-mixin-40(222): Deprecation: `opDot` is deprecated. Use `alias this`
runnable/xtest46_gc.d-mixin-40(223): Deprecation: `opDot` is deprecated. Use `alias this`
runnable/xtest46_gc.d-mixin-40(225): Deprecation: `opDot` is deprecated. Use `alias this`
const(int)
string[]
double[]
double[]
{}
runnable/xtest46_gc.d-mixin-40(4638): Deprecation: alias this for classes is deprecated
tuple("m")
true
TFunction1: extern (C) void function()
---
*/

mixin(import("xtest46.d"));
