/*
REQUIRED_ARGS: -preview=in -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/previewin.d(3): Error: function `previewin.func1(void function(ulong[8]) dg)` is not callable using argument types `(void function(in ulong[8]))`
fail_compilation/previewin.d(3):        cannot pass argument `& func_byRef` of type `void function(in ulong[8])` to parameter `void function(ulong[8]) dg`
fail_compilation/previewin.d(4): Error: function `previewin.func2(void function(ref ulong[8]) dg)` is not callable using argument types `(void function(in ulong[8]))`
fail_compilation/previewin.d(4):        cannot pass argument `& func_byRef` of type `void function(in ulong[8])` to parameter `void function(ref ulong[8]) dg`
fail_compilation/previewin.d(7): Error: function `previewin.func4(void function(ref uint) dg)` is not callable using argument types `(void function(in uint))`
fail_compilation/previewin.d(7):        cannot pass argument `& func_byValue` of type `void function(in uint)` to parameter `void function(ref uint) dg`
fail_compilation/previewin.d(41): Error: scope variable `arg` assigned to non-scope `myGlobal`
fail_compilation/previewin.d(42): Error: scope variable `arg` assigned to non-scope `myGlobal`
fail_compilation/previewin.d(43): Error: scope variable `arg` may not be returned
fail_compilation/previewin.d(44): Error: scope variable `arg` assigned to `escape` with longer lifetime
fail_compilation/previewin.d(48): Error: returning `arg` escapes a reference to parameter `arg`
fail_compilation/previewin.d(48):        perhaps annotate the parameter with `return`
---
 */

#line 1
void main ()
{
    func1(&func_byRef); // No
    func2(&func_byRef); // No
    func3(&func_byRef); // Could be Yes, but currently No

    func4(&func_byValue); // No
    func5(&func_byValue); // Yes

    func6(&func_byValue2); // Yes
    func7(&func_byValue3); // Yes

    tryEscape("Hello World"); // Yes by `tryEscape` is NG
}

// Takes by `scope ref const`
void func_byRef(in ulong[8]) {}
// Takes by `scope const`
void func_byValue(in uint) {}

// Error: `ulong[8]` is passed by `ref`
void func1(void function(scope ulong[8]) dg) {}
// Error: Missing `scope` on a `ref`
void func2(void function(ref ulong[8]) dg) {}
// Works: `scope ref`
void func3(void function(scope const ref ulong[8]) dg) {}

// Error: `uint` is passed by value
void func4(void function(ref uint) dg) {}
// Works: By value `scope const`
void func5(void function(scope const uint) dg) {}

// This works for arrays:
void func_byValue2(in char[]) {}
void func6(void function(char[]) dg) {}
void func_byValue3(scope const(char)[]) {}
void func7(void function(in char[]) dg) {}

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
