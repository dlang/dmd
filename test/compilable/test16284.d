// https://issues.dlang.org/show_bug.cgi?id=16284

struct S {}

struct T
{
    union {int i; S s;}
    this(uint dummy) { s = S.init; }
}

static assert(T(0) == T(0));
