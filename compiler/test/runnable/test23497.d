
class A {}

A getA(T t) {
        return t.a;
}

struct T {
        A _a;

        void k() {}

        @property
        auto a() in {
                k();
        } do {
                return _a;
        }
}

void main() {}
