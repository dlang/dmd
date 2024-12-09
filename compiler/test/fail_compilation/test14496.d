/*
TEST_OUTPUT:
---
fail_compilation/test14496.d(33): Error: `void` initializers for pointers not allowed in safe functions
    Foo f = void;
        ^
fail_compilation/test14496.d(36): Error: `void` initializers for pointers not allowed in safe functions
        Foo foo = void;
            ^
fail_compilation/test14496.d(40): Error: `void` initializers for pointers not allowed in safe functions
        int* x = void;
             ^
fail_compilation/test14496.d(60): Error: `void` initializers for pointers not allowed in safe functions
    Bar bar;
        ^
fail_compilation/test14496.d(61): Error: `void` initializers for pointers not allowed in safe functions
    Baz baz;
        ^
fail_compilation/test14496.d(62): Error: `void` initializers for pointers not allowed in safe functions
    Bar[2] bars; // https://issues.dlang.org/show_bug.cgi?id=23412
           ^
---
*/
// https://issues.dlang.org/show_bug.cgi?id=14496
@safe void foo()
{
    struct Foo {
        int* indirection1;
        Object indirection2;
        string[] indirection3;
    }

    Foo f = void;

    struct Bar {
        Foo foo = void;
    }

    struct Baz {
        int* x = void;
    }
}


struct Foo {
    int* indirection1;
    Object indirection2;
    string[] indirection3;
}

struct Bar {
    Foo foo = void;
}

struct Baz {
    int* x = void;
}

@safe void sinister() {
    Bar bar;
    Baz baz;
    Bar[2] bars; // https://issues.dlang.org/show_bug.cgi?id=23412
}
