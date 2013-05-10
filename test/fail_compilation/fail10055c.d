struct S {
    ~this() { }
}

struct SX {
    S s;
    @safe ~this() { }
}


void main() { }
