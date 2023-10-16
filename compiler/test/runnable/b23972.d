interface I { void g(); }
interface I1 : I { void g1(); }
interface I2 : I { void g2(); }
interface J : I1, I2 { void h(); }

class C : J
{
    override void g() { }
    override void g1() { }
    override void g2() { }
    override void h() { }
}

void main() @safe
{
    C c = new C;
    I i1 = cast(I1) c;
    I i2 = cast(I2) c;
    assert(cast(Object) i1 is cast(Object) i2); // good
    assert(i1 is i2); // fails
    assert(i2 is i1); // fails
    assert(c is i2); // fails
    assert(i2 is c); // fails
    assert(c is cast(C) i2); // good
    assert(c is cast(Object) i2); // good
    assert(i1 is c); // good

    shared(I) i3, i4;
    assert(i3 is null);
    assert(i3 is i4);
}
