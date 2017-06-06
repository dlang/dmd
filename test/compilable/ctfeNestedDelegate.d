void opApply(void delegate() dlg) { dlg(); }

struct Foo {
    int i;

    int abc() {
        void dg() { i = 0; }
        opApply(&dg);
        return 0;
    }
}

void bar() {
    enum x = Foo().abc();
}

struct OpApply {
    int opApply(scope int delegate(int) dlg) {
        return dlg(1);
    }
}

struct Foo2 {
    int i;
    this(int x) {
        foreach(_; OpApply()) {
            i = 0; // Error: couldn't find field i of type int in OpApply()
        }
    }
}

enum x = Foo2(1);
