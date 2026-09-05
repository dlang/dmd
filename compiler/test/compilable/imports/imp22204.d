template O() {}

mixin template G() {
    void Foo() {}
}

final class D {
    alias L = () {};
    mixin G;
}
