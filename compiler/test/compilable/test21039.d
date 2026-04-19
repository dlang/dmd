// https://github.com/dlang/dmd/issues/21039
// Zero-length static array with scalar initializer caused ICE

struct A { const(char)[0] b = 0; }
struct B { int[0] x = 5 + 5; }
