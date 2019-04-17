/* TEST_OUTPUT:
---
---
*/
class Inner
{
    int a;
}

class Outer
{
    Inner inner; alias inner this;
    this(Inner i) { inner = i; }
}

void main()
{
    Inner[] inners = [];
    inners ~= new Inner;
    inners ~= new Outer(new Inner); // Appends null

    foreach(inner; inners)
    {
        assert(inner.a == 0);
    }
}
