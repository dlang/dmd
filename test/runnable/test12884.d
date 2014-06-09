/* implicit conversion wrongly prefers casting immutable away over alias this when target type is base class */
class B {int x;}
class C : B
{
    this(int x) pure {this.x = x;}
    @property C mutable() const {return new C(42);}
    alias mutable this;
}
void main()
{
    immutable c = new C(1);
    B m1 = c; /* should call alias this */
    assert(m1.x == 42);
    assert(m1 !is c);
}
