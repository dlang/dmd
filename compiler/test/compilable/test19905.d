// https://github.com/dlang/dmd/issues/19905
// Type list (tuple) not expanded in delegate during IFTI

alias AliasSeq(TList...) = TList;

struct S
{
    void m() {}
}

void fun1(R)(R delegate(AliasSeq!S) dg) {}
void fun2(R)(R delegate(AliasSeq!(S, S)) dg) {}
void fun3(R)(R delegate(AliasSeq!(S, S, S)) dg) {}
void fun0(R)(R delegate(AliasSeq!()) dg) {}

void main()
{
    // Explicit template argument always worked
    fun1!void((a) { a.m(); });
    fun2!void((a, b) { a.m(); b.m(); });
    fun3!void((a, b, c) { a.m(); b.m(); c.m(); });
    fun0!void(() {});

    // IFTI with tuple expansion - was broken, now fixed
    fun1((a) { a.m(); });
    fun2((a, b) { a.m(); b.m(); });
    fun3((a, b, c) { a.m(); b.m(); c.m(); });
    fun0(() {});
}
