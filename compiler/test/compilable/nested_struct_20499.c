// https://github.com/dlang/dmd/issues/20499


struct Outer {
    struct __attribute__((aligned(8))) {
        int x;
    } n;
    enum {A};
    enum {B} b;
};

struct Outer2 {
    struct __attribute__((aligned(8))) Nested {
        int x;
    } n;
};

const int x = A;
const int y = B;

struct Outer o = {3};
_Static_assert(_Alignof(typeof(o.n)) == 8, "");
_Static_assert(_Alignof(struct Outer) == 8, "");
_Static_assert(_Alignof(struct Outer2) == 8, "");
_Static_assert(_Alignof(struct Nested) == 8, "");

void test(void){
    struct Outer {
        struct __attribute__((aligned(16))) {
            int x;
        } n;
        enum {A=2};
        enum {B=3} b;
    };

    struct Outer2 {
        struct __attribute__((aligned(16))) Nested {
            int x;
        } n;
    };

    const int x = A;
    const int y = B;

    struct Outer o = {3};
    _Static_assert(_Alignof(typeof(o.n)) == 16, "");
    _Static_assert(_Alignof(struct Outer) == 16, "");
    _Static_assert(_Alignof(struct Outer2) == 16, "");
    _Static_assert(_Alignof(struct Nested) == 16, "");
}

void test2(void){
    const int x = A;
    const int y = B;

    struct Outer o = {3};
    _Static_assert(_Alignof(typeof(o.n)) == 8, "");
    _Static_assert(_Alignof(struct Outer) == 8, "");
    _Static_assert(_Alignof(struct Outer2) == 8, "");
    _Static_assert(_Alignof(struct Nested) == 8, "");
}
