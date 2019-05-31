// https://issues.dlang.org/show_bug.cgi?id=18439
// Internally `static foreach` builds an array using `~=` for ranges which uses the GC
// this would cause a compiler error when @nogc is used, even though the code is only run at compile time

// error specifically occurs when @nogc is applied to a scope
@nogc:

void test() {
    static foreach(i; 0 .. 1) {}
}
