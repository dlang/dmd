
// https://issues.dlang.org/show_bug.cgi?id=23030

typedef struct {
    int i;
} S1;
const S1 unused;
S1 s;
void fn() { int i = s.i; } // Error: need `this` for `i` of type `int`

typedef struct {
    int a,b;
} S2;
const S2 aaa = { 0,0 };
S2 bbb = { 0,0 }; // Error: 1 extra initializer(s) for `struct __tag3`
