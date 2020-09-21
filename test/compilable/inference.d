// https://issues.dlang.org/show_bug.cgi?id=13567

private void dfunc1 () { }
private void dfunc2 () { throw new Exception("Hello World"); }
private extern(C) void dfunc3 () { }
private extern(C++) void dfunc4 () { }

void caller1() @safe pure nothrow @nogc {
    dfunc1();
    dfunc3();
    dfunc4();
}
void caller2() @safe pure {
    dfunc2();
}
