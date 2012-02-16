// EXTRA_SOURCES: imports/test2225.d
module test2225;

import imports.test2225;

void main()
{
    auto o = new Outer;
    o.a = 3;
    static assert(!is(typeof(Outer.Inner)));
    static assert(!is(typeof(() { Outer.Inner oi; })));
    auto oi = o.makeInner();
    assert(oi.foo() == 3);
    typeof(o.makeInner()) oi2;
    oi2 = cast(typeof(oi))oi.classinfo.create();
    oi2.outer = o;
    assert(oi2.foo() == 3);
}
