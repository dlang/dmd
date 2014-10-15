/*
TEST_OUTPUT:
---
fail_compilation/diag13074.d(29): Error: AA key type S now requires equality rather than comparison
fail_compilation/diag13074.d(29):        Please define opEquals, or remove opCmp to also rely on default memberwise comparison.
---
*/
struct S
{
    int x;
    int y;

    int opCmp(ref const S other) const
    {
        return x < other.x ? -1 : x > other.x ? 1 : 0;
    }
    hash_t toHash() const
    {
        return x;
    }
}

void main()
{
    S s1 = S(1, 1);
    S s2 = S(1, 2);
    S s3 = S(2, 1);
    S s4 = S(2, 2);
    bool[S] arr;
    arr[s1] = true;
    arr[s2] = true;
    arr[s3] = true;
    arr[s4] = true;
}

/*
TEST_OUTPUT:
---
fail_compilation/diag13074.d(70): Error: AA key type C now requires equality rather than comparison
fail_compilation/diag13074.d(70):        Please override Object.opEquals and toHash.
---
*/
class C
{
    int x;
    int y;
    this(int x, int y)
    {
        this.x = x; this.y = y;
    }

    override int opCmp(Object other)
    {
        if (auto o = cast(C)other)
            return x < o.x ? -1 : x > o.x ? 1 : 0;
        return -1;
    }
    override hash_t toHash() const
    {
        return x;
    }
}

void test13114()
{
    const c1 = new C(1,1);
    const c2 = new C(1,2);
    const c3 = new C(2,1);
    const c4 = new C(2,2);
    bool[const(C)] arr;
    arr[c1] = true;
    arr[c2] = true;
    arr[c3] = true;
    arr[c4] = true;
}
