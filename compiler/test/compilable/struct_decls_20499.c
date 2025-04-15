// https://github.com/dlang/dmd/issues/20499

//
// attribute((aligned())) is so we can tell if attributes are being applied.
//
typedef struct __attribute__((aligned(8))) S {
    int x, y;
} S;
_Static_assert(sizeof(struct S) == 8, "sizeof(S)");
_Static_assert(_Alignof(struct S) == 8, "_Alignof(S)");

typedef struct __attribute__((aligned(8))) Foo {
    int x, y;
} *pFoo, Foo, FooB;

_Static_assert(sizeof(struct Foo) == sizeof(struct S), "sizeof(Foo)");
_Static_assert(_Alignof(struct Foo) == _Alignof(struct S), "_Alignof(Foo)");
_Static_assert(sizeof(Foo) == sizeof(struct S), "sizeof(Foo)");
_Static_assert(_Alignof(Foo) == _Alignof(struct S), "_Alignof(Foo)");
_Static_assert(sizeof(FooB) == sizeof(struct S), "sizeof(FooB)");
_Static_assert(_Alignof(FooB) == _Alignof(struct S), "_Alignof(FooB)");

pFoo pf;
_Static_assert(sizeof(*pf) == sizeof(struct S), "sizeof(*pf)");
_Static_assert(_Alignof(typeof(*pf)) == _Alignof(struct S), "_Alignof(*pf)");

typedef struct __attribute__((aligned(8))) {
    int x, y;
} Baz, *pBaz, BazB;
_Static_assert(sizeof(Baz) == sizeof(struct S), "sizeof(Baz)");
_Static_assert(sizeof(BazB) == sizeof(struct S), "sizeof(BazB)");
_Static_assert(_Alignof(Baz) == _Alignof(struct S), "_Alignof(Baz)");
_Static_assert(_Alignof(BazB) == _Alignof(struct S), "_Alignof(BazB)");

pBaz pb;
_Static_assert(sizeof(*pb) == sizeof(struct S), "sizeof(*pb)");
_Static_assert(_Alignof(typeof(*pb)) == _Alignof(struct S), "_Alignof(*pb)");

typedef struct __attribute__((aligned(8))) {
    int x, y;
} *pTux;
pTux pt;
_Static_assert(sizeof(*pt) == sizeof(struct S), "sizeof(*pt)");
_Static_assert(_Alignof(typeof(*pt)) == _Alignof(struct S), "_Alignof(*pt)");

typedef struct __attribute__((aligned(8))) {
    int x, y;
} Qux;
_Static_assert(sizeof(Qux) == sizeof(struct S), "sizeof(FooB)");
_Static_assert(_Alignof(Qux) == _Alignof(struct S), "_Alignof(FooB)");

struct Bar {
    struct S foo;
};
_Static_assert(sizeof(struct Bar) == sizeof(struct S), "sizeof(Bar)");
_Static_assert(_Alignof(struct Bar) == _Alignof(struct S), "_Alignof(Bar)");

typedef struct __attribute__((aligned(8))) {
    int x, y;
} *pLux;
pLux pl;
_Static_assert(sizeof(*pl) == sizeof(struct S), "sizeof(*pl)");
_Static_assert(_Alignof(typeof(*pl)) == _Alignof(struct S), "_Alignof(*pl)");


typedef struct __attribute__((aligned(8))) {
    int x, y;
} ****pWux;
pWux pw;
_Static_assert(sizeof(****pw) == sizeof(struct S), "sizeof(****pw)");
_Static_assert(_Alignof(typeof(****pw)) == _Alignof(struct S), "_Alignof(****pw)");

struct __attribute__((aligned(8))) {
    int x, y;
} f;
_Static_assert(sizeof(f) == sizeof(struct S), "sizeof(f)");
_Static_assert(_Alignof(typeof(f)) == _Alignof(struct S), "_Alignof(f)");

struct __attribute__((aligned(8))) {
    int x, y;
} fa[3];
_Static_assert(sizeof(fa[0]) == sizeof(struct S), "sizeof(fa[0])");
_Static_assert(_Alignof(typeof(fa[0])) == _Alignof(struct S), "_Alignof(fa[0])");

void locals(void){
    // function local version
    // Use different values so we know we aren't just using globals
    typedef struct __attribute__((aligned(16))) S {
        int x, y[7];
    } S;
    _Static_assert(sizeof(struct S) == 32, "sizeof(S)");
    _Static_assert(_Alignof(struct S) == 16, "_Alignof(S)");

    typedef struct __attribute__((aligned(16))) Foo {
        int x, y[7];
    } *pFoo, Foo, FooB;

    _Static_assert(sizeof(struct Foo) == sizeof(struct S), "sizeof(Foo)");
    _Static_assert(_Alignof(struct Foo) == _Alignof(struct S), "_Alignof(Foo)");
    _Static_assert(sizeof(Foo) == sizeof(struct S), "sizeof(Foo)");
    _Static_assert(_Alignof(Foo) == _Alignof(struct S), "_Alignof(Foo)");
    _Static_assert(sizeof(FooB) == sizeof(struct S), "sizeof(FooB)");
    _Static_assert(_Alignof(FooB) == _Alignof(struct S), "_Alignof(FooB)");

    pFoo pf;
    _Static_assert(sizeof(*pf) == sizeof(struct S), "sizeof(*pf)");
    _Static_assert(_Alignof(typeof(*pf)) == _Alignof(struct S), "_Alignof(*pf)");

    typedef struct __attribute__((aligned(16))) {
        int x, y[7];
    } Baz, *pBaz, BazB;
    _Static_assert(sizeof(Baz) == sizeof(struct S), "sizeof(Baz)");
    _Static_assert(sizeof(BazB) == sizeof(struct S), "sizeof(BazB)");
    _Static_assert(_Alignof(Baz) == _Alignof(struct S), "_Alignof(Baz)");
    _Static_assert(_Alignof(BazB) == _Alignof(struct S), "_Alignof(BazB)");


    pBaz pb;
    _Static_assert(sizeof(*pb) == sizeof(struct S), "sizeof(*pb)");
    _Static_assert(_Alignof(typeof(*pb)) == _Alignof(struct S), "_Alignof(*pb)");


    typedef struct __attribute__((aligned(16))) {
        int x, y[7];
    } *pTux;
    pTux pt;
    _Static_assert(sizeof(*pt) == sizeof(struct S), "sizeof(*pt)");
    _Static_assert(_Alignof(typeof(*pt)) == _Alignof(struct S), "_Alignof(*pt)");


    typedef struct __attribute__((aligned(16))) {
        int x, y[7];
    } Qux;
    _Static_assert(sizeof(Qux) == sizeof(struct S), "sizeof(FooB)");
    _Static_assert(_Alignof(Qux) == _Alignof(struct S), "_Alignof(FooB)");

    struct Bar {
        struct S foo;
    };
    _Static_assert(sizeof(struct Bar) == sizeof(struct S), "sizeof(Bar)");
    _Static_assert(_Alignof(struct Bar) == _Alignof(struct S), "_Alignof(Bar)");

    typedef struct __attribute__((aligned(16))) {
        int x, y[7];
    } *pLux;
    pLux pl;
    _Static_assert(sizeof(*pl) == sizeof(struct S), "sizeof(*pl)");
    _Static_assert(_Alignof(typeof(*pl)) == _Alignof(struct S), "_Alignof(*pl)");


    typedef struct __attribute__((aligned(16))) {
        int x, y[7];
    } ****pWux;
    pWux pw;
    _Static_assert(sizeof(****pw) == sizeof(struct S), "sizeof(****pw)");
    _Static_assert(_Alignof(typeof(****pw)) == _Alignof(struct S), "_Alignof(****pw)");

    struct __attribute__((aligned(16))) {
        int x, y[7];
    } f;
    _Static_assert(sizeof(f) == sizeof(struct S), "sizeof(f)");
    _Static_assert(_Alignof(typeof(f)) == _Alignof(struct S), "_Alignof(f)");
    // Verify shadowing works
    {
        typedef struct __attribute__((aligned(32))) S {
            int x, y[15];
        } S;
        _Static_assert(sizeof(struct S) == 64, "sizeof(S)");
        _Static_assert(_Alignof(struct S) == 32, "_Alignof(S)");

        typedef struct __attribute__((aligned(32))) Foo {
            int x, y[15];
        } *pFoo, Foo, FooB;

        _Static_assert(sizeof(struct Foo) == sizeof(struct S), "sizeof(Foo)");
        _Static_assert(_Alignof(struct Foo) == _Alignof(struct S), "_Alignof(Foo)");
        _Static_assert(sizeof(Foo) == sizeof(struct S), "sizeof(Foo)");
        _Static_assert(_Alignof(Foo) == _Alignof(struct S), "_Alignof(Foo)");
        _Static_assert(sizeof(FooB) == sizeof(struct S), "sizeof(FooB)");
        _Static_assert(_Alignof(FooB) == _Alignof(struct S), "_Alignof(FooB)");

        pFoo pf;
        _Static_assert(sizeof(*pf) == sizeof(struct S), "sizeof(*pf)");
        _Static_assert(_Alignof(typeof(*pf)) == _Alignof(struct S), "_Alignof(*pf)");

        typedef struct __attribute__((aligned(32))) {
            int x, y[15];
        } Baz, *pBaz, BazB;
        _Static_assert(sizeof(Baz) == sizeof(struct S), "sizeof(Baz)");
        _Static_assert(sizeof(BazB) == sizeof(struct S), "sizeof(BazB)");
        _Static_assert(_Alignof(Baz) == _Alignof(struct S), "_Alignof(Baz)");
        _Static_assert(_Alignof(BazB) == _Alignof(struct S), "_Alignof(BazB)");


        pBaz pb;
        _Static_assert(sizeof(*pb) == sizeof(struct S), "sizeof(*pb)");
        _Static_assert(_Alignof(typeof(*pb)) == _Alignof(struct S), "_Alignof(*pb)");


        typedef struct __attribute__((aligned(32))) {
            int x, y[15];
        } *pTux;
        pTux pt;
        _Static_assert(sizeof(*pt) == sizeof(struct S), "sizeof(*pt)");
        _Static_assert(_Alignof(typeof(*pt)) == _Alignof(struct S), "_Alignof(*pt)");


        typedef struct __attribute__((aligned(32))) {
            int x, y[15];
        } Qux;
        _Static_assert(sizeof(Qux) == sizeof(struct S), "sizeof(FooB)");
        _Static_assert(_Alignof(Qux) == _Alignof(struct S), "_Alignof(FooB)");

        struct Bar {
            struct S foo;
        };
        _Static_assert(sizeof(struct Bar) == sizeof(struct S), "sizeof(Bar)");
        _Static_assert(_Alignof(struct Bar) == _Alignof(struct S), "_Alignof(Bar)");

        typedef struct __attribute__((aligned(32))) {
            int x, y[15];
        } *pLux;
        pLux pl;
        _Static_assert(sizeof(*pl) == sizeof(struct S), "sizeof(*pl)");
        _Static_assert(_Alignof(typeof(*pl)) == _Alignof(struct S), "_Alignof(*pl)");


        typedef struct __attribute__((aligned(32))) {
            int x, y[15];
        } ****pWux;
        pWux pw;
        _Static_assert(sizeof(****pw) == sizeof(struct S), "sizeof(****pw)");
        _Static_assert(_Alignof(typeof(****pw)) == _Alignof(struct S), "_Alignof(****pw)");

        struct __attribute__((aligned(32))) {
            int x, y[15];
        } f;
        _Static_assert(sizeof(f) == sizeof(struct S), "sizeof(f)");
        _Static_assert(_Alignof(typeof(f)) == _Alignof(struct S), "_Alignof(f)");
    }
}

void globals(void){
    _Static_assert(sizeof(struct S) == 8, "sizeof(S)");
    _Static_assert(_Alignof(struct S) == 8, "_Alignof(S)");

    _Static_assert(sizeof(struct Foo) == sizeof(struct S), "sizeof(Foo)");
    _Static_assert(_Alignof(struct Foo) == _Alignof(struct S), "_Alignof(Foo)");
    _Static_assert(sizeof(Foo) == sizeof(struct S), "sizeof(Foo)");
    _Static_assert(_Alignof(Foo) == _Alignof(struct S), "_Alignof(Foo)");
    _Static_assert(sizeof(FooB) == sizeof(struct S), "sizeof(FooB)");
    _Static_assert(_Alignof(FooB) == _Alignof(struct S), "_Alignof(FooB)");

    pFoo pf;
    _Static_assert(sizeof(*pf) == sizeof(struct S), "sizeof(*pf)");
    _Static_assert(_Alignof(typeof(*pf)) == _Alignof(struct S), "_Alignof(*pf)");

    _Static_assert(sizeof(Baz) == sizeof(struct S), "sizeof(Baz)");
    _Static_assert(sizeof(BazB) == sizeof(struct S), "sizeof(BazB)");
    _Static_assert(_Alignof(Baz) == _Alignof(struct S), "_Alignof(Baz)");
    _Static_assert(_Alignof(BazB) == _Alignof(struct S), "_Alignof(BazB)");

    pBaz pb;
    _Static_assert(sizeof(*pb) == sizeof(struct S), "sizeof(*pb)");
    _Static_assert(_Alignof(typeof(*pb)) == _Alignof(struct S), "_Alignof(*pb)");

    pTux pt;
    _Static_assert(sizeof(*pt) == sizeof(struct S), "sizeof(*pt)");
    _Static_assert(_Alignof(typeof(*pt)) == _Alignof(struct S), "_Alignof(*pt)");

    _Static_assert(sizeof(Qux) == sizeof(struct S), "sizeof(FooB)");
    _Static_assert(_Alignof(Qux) == _Alignof(struct S), "_Alignof(FooB)");

    _Static_assert(sizeof(struct Bar) == sizeof(struct S), "sizeof(Bar)");
    _Static_assert(_Alignof(struct Bar) == _Alignof(struct S), "_Alignof(Bar)");

    pLux pl;
    _Static_assert(sizeof(*pl) == sizeof(struct S), "sizeof(*pl)");
    _Static_assert(_Alignof(typeof(*pl)) == _Alignof(struct S), "_Alignof(*pl)");


    pWux pw;
    _Static_assert(sizeof(****pw) == sizeof(struct S), "sizeof(****pw)");
    _Static_assert(_Alignof(typeof(****pw)) == _Alignof(struct S), "_Alignof(****pw)");
    Foo foo = {1, 2, 3};
    struct Foo foo2 = {1, 2, 3};
}
