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

// https://github.com/dlang/dmd/issues/22681
C foo22681(Object o) {
    return cast(C) (o ? o : null);
}

void main() {
    assert(foo() is null);
    assert(foo22681(new Object) is null);
}
