struct S1 {
    ~this() nothrow pure @safe { }
}

struct S2 {
    @safe ~this() pure nothrow { }
}

void main() nothrow pure @safe {
    S1 s1;
    S2 s2;
}
