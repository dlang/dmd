/*
TEST_OUTPUT:
---
fail_compilation/b20011.d(22): Error: cannot modify constant expression `S1(cast(ubyte)0u).member`
fail_compilation/b20011.d(25): Error: cannot modify constant expression `S2(null).member`
fail_compilation/b20011.d(26): Error: cannot modify constant expression `S2(null).member`
fail_compilation/b20011.d(27): Error: cannot modify constant expression `S2(null).member`
fail_compilation/b20011.d(30): Error: cannot modify constant expression `U1(cast(ubyte)0u, ).m2`
fail_compilation/b20011.d(34): Error: cannot modify constant expression `S1(cast(ubyte)0u).member`
fail_compilation/b20011.d(35): Error: cannot modify constant expression `S1(cast(ubyte)0u).member`
---
*/
module b20011;

struct S1 { ubyte member;     }
struct S2 { ubyte[] member;   }
union U1  { ubyte m1; int m2; }

void main()
{
    enum S1 s1 = {};
    s1.member = 42;

    enum S2 s2 = {};
    s2.member = [];
    s2.member ~= [];
    s2.member += [];

    enum U1 u1 = {m1 : 0};
    u1.m2 = 42;

    void assignableByRef(ref ubyte p){ p = 42; }
    void assignableByOut(out ubyte p){ p = 42; }
    assignableByRef(s1.member);
    assignableByOut(s1.member);
} 
