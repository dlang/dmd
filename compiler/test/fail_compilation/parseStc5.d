/*
TEST_OUTPUT:
---
fail_compilation/parseStc5.d(65): Error: constructor cannot be static
    static pure this(int) {}        // `static pure` + `this(int)`
                ^
fail_compilation/parseStc5.d(66): Error: postblit cannot be `static`
    static pure this(this) {}       // `static pure` + `this(this)`
                ^
fail_compilation/parseStc5.d(71): Error: use `shared static this()` to declare a shared static constructor
    shared pure static this() {}    // `shared pure` + `static this()`
                ^
fail_compilation/parseStc5.d(72): Error: use `shared static this()` to declare a shared static constructor
    shared static pure this() {}    // `shared static pure` + `this()`
                       ^
fail_compilation/parseStc5.d(74): Error: use `shared static this()` to declare a shared static constructor
    static this() shared {}         // `shared pure` + `static this()`
    ^
fail_compilation/parseStc5.d(76): Error: use `shared static ~this()` to declare a shared static destructor
    shared pure static ~this() {}   // `shared pure` + `static ~this()`
                ^
fail_compilation/parseStc5.d(77): Error: use `shared static ~this()` to declare a shared static destructor
    shared static pure ~this() {}   // `shared static pure` + `~this()`
                       ^
fail_compilation/parseStc5.d(79): Error: use `shared static ~this()` to declare a shared static destructor
    static ~this() shared {}        // `shared` + `static ~this()`
    ^
fail_compilation/parseStc5.d(84): Error: use `static this()` to declare a static constructor
    static pure this() {}           // `static pure` + `this()`
                ^
fail_compilation/parseStc5.d(85): Error: use `static ~this()` to declare a static destructor
    static pure ~this() {}          // `static pure` + `~this()`
                ^
fail_compilation/parseStc5.d(90): Error: redundant attribute `shared`
    shared shared static this() {}                  // `shared` + `shared static this()`
                                ^
fail_compilation/parseStc5.d(91): Error: redundant attribute `shared`
    shared static this() shared {}                  // `shared` + `shared static this()`
                                ^
fail_compilation/parseStc5.d(93): Error: redundant attribute `static`
    static static this() {}                         // `static` + `shared static this()`
                         ^
fail_compilation/parseStc5.d(95): Error: redundant attribute `static shared`
    shared static shared static this() {}           // shared static + `shared static this()`
                                       ^
fail_compilation/parseStc5.d(96): Error: redundant attribute `static shared`
    shared static shared static this() shared {}    // shared shared static + `shared static this()`
                                              ^
fail_compilation/parseStc5.d(101): Error: static constructor cannot be `const`
    static this() const {}
    ^
fail_compilation/parseStc5.d(102): Error: static destructor cannot be `const`
    static ~this() const {}
    ^
fail_compilation/parseStc5.d(103): Error: shared static constructor cannot be `const`
    shared static this() const {}
    ^
fail_compilation/parseStc5.d(104): Error: shared static destructor cannot be `const`
    shared static ~this() const {}
    ^
---
*/
class C1
{
    static pure this(int) {}        // `static pure` + `this(int)`
    static pure this(this) {}       // `static pure` + `this(this)`
}

class C2    // wrong combinations of `shared`, `static`, and `~?this()`
{
    shared pure static this() {}    // `shared pure` + `static this()`
    shared static pure this() {}    // `shared static pure` + `this()`

    static this() shared {}         // `shared pure` + `static this()`

    shared pure static ~this() {}   // `shared pure` + `static ~this()`
    shared static pure ~this() {}   // `shared static pure` + `~this()`

    static ~this() shared {}        // `shared` + `static ~this()`
}

class C3    // wrong combinations of `static` and `~?this()`
{
    static pure this() {}           // `static pure` + `this()`
    static pure ~this() {}          // `static pure` + `~this()`
}

class C4    // redundancy of `shared` and/or `static`
{
    shared shared static this() {}                  // `shared` + `shared static this()`
    shared static this() shared {}                  // `shared` + `shared static this()`

    static static this() {}                         // `static` + `shared static this()`

    shared static shared static this() {}           // shared static + `shared static this()`
    shared static shared static this() shared {}    // shared shared static + `shared static this()`
}

class C5    // wrong MemberFunctionAttributes on `shared? static (con|de)structor`
{
    static this() const {}
    static ~this() const {}
    shared static this() const {}
    shared static ~this() const {}
}
