// https://github.com/dlang/dmd/issues/22422

class C {}
class D {}

struct S {
    ~this() {}
    D opIndex(size_t) { return new D; }
}

S makeS() {
    return S();
}

C foo() {
    return cast(C) makeS()[0];
}

void main() {
    assert(foo() is null);
}
