/*
TEST_OUTPUT:
---
C22766()
---
*/
module object;

class C22766 { }

pragma(msg, new C22766);

// https://github.com/dlang/dmd/issues/24470
class C24470
{
    int x;
    this(int x) { this.x = x; }
}

__gshared C24470 a = new C24470(42);
