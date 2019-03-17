enum X;
static assert(X.sizeof == 4);
enum Y : ulong;
static assert(Y.sizeof == 8);
struct Foo {ubyte[X.sizeof + Y.sizeof] _;}
enum Z : Foo;
static assert(Z.sizeof == 12);
