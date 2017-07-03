// REQUIRED_ARGS: -o-

auto foo(int a, bool b) @nogc {
    static struct SInside {}

    SInside res;

    lazyfun(a);

    return res;
}


void lazyfun(scope lazy int a) @nogc;
