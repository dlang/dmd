/*
REQUIRED_ARGS: -preview=in -preview=dip1000
TEST_OUTPUT:
----
fail_compilation/previewin.d(51): Error: function `takeFunction` is not callable using argument types `(void function(real x) pure nothrow @nogc @safe)`
    takeFunction((real x) {});
                ^
fail_compilation/previewin.d(51):        cannot pass argument `__lambda_L51_C18` of type `void function(real x) pure nothrow @nogc @safe` to parameter `void function(in real) f`
fail_compilation/previewin.d(58):        `previewin.takeFunction(void function(in real) f)` declared here
void takeFunction(void function(in real) f);
     ^
fail_compilation/previewin.d(52): Error: function `takeFunction` is not callable using argument types `(void function(scope const(real) x) pure nothrow @nogc @safe)`
    takeFunction((const scope real x) {});
                ^
fail_compilation/previewin.d(52):        cannot pass argument `__lambda_L52_C18` of type `void function(scope const(real) x) pure nothrow @nogc @safe` to parameter `void function(in real) f`
fail_compilation/previewin.d(58):        `previewin.takeFunction(void function(in real) f)` declared here
void takeFunction(void function(in real) f);
     ^
fail_compilation/previewin.d(53): Error: function `takeFunction` is not callable using argument types `(void function(ref scope const(real) x) pure nothrow @nogc @safe)`
    takeFunction((const scope ref real x) {});
                ^
fail_compilation/previewin.d(53):        cannot pass argument `__lambda_L53_C18` of type `void function(ref scope const(real) x) pure nothrow @nogc @safe` to parameter `void function(in real) f`
fail_compilation/previewin.d(58):        `previewin.takeFunction(void function(in real) f)` declared here
void takeFunction(void function(in real) f);
     ^
fail_compilation/previewin.d(62): Error: scope variable `arg` assigned to global variable `myGlobal`
void tryEscape(in char[] arg) @safe { myGlobal = arg; }
                                               ^
fail_compilation/previewin.d(63): Error: scope variable `arg` assigned to global variable `myGlobal`
void tryEscape2(scope const char[] arg) @safe { myGlobal = arg; }
                                                         ^
fail_compilation/previewin.d(64): Error: scope parameter `arg` may not be returned
const(char)[] tryEscape3(in char[] arg) @safe { return arg; }
                                                       ^
fail_compilation/previewin.d(65): Error: scope variable `arg` assigned to `ref` variable `escape` with longer lifetime
void tryEscape4(in char[] arg, ref const(char)[] escape) @safe { escape = arg; }
                                                                        ^
fail_compilation/previewin.d(69): Error: returning `arg` escapes a reference to parameter `arg`
ref const(ulong[8]) tryEscape6(in ulong[8] arg) @safe { return arg; }
                                                               ^
fail_compilation/previewin.d(69):        perhaps annotate the parameter with `return`
ref const(ulong[8]) tryEscape6(in ulong[8] arg) @safe { return arg; }
                                       ^
----
 */

// Line 1 starts here
void main ()
{
    // No covariance without explicit `in`
    takeFunction((real x) {});
    takeFunction((const scope real x) {});
    takeFunction((const scope ref real x) {});

    tryEscape("Hello World"); // Yes by `tryEscape` is NG
}

void takeFunction(void function(in real) f);

// Make sure things cannot be escaped (`scope` is applied)
const(char)[] myGlobal;
void tryEscape(in char[] arg) @safe { myGlobal = arg; }
void tryEscape2(scope const char[] arg) @safe { myGlobal = arg; }
const(char)[] tryEscape3(in char[] arg) @safe { return arg; }
void tryEscape4(in char[] arg, ref const(char)[] escape) @safe { escape = arg; }
// Okay: value type
ulong[8] tryEscape5(in ulong[8] arg) @safe { return arg; }
// NG: Ref
ref const(ulong[8]) tryEscape6(in ulong[8] arg) @safe { return arg; }
