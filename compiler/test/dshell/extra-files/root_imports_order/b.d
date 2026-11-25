module b;

import x;

struct S(T)
{
    static int get() { return 42; }
}

S!int fromB;
