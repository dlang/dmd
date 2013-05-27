struct S {
    @disable this();

    this(int i) {
    }
}

class C {
    this() {
        s = S(1);
    }

    S s;
}

void main() {
    auto c = new C;
}
