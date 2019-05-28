/*
TEST_OUTPUT:
---
---
*/

struct HasDestructor
{
    ~this()
    {
        ++d;
    }
    this(this)
    {
        ++p;
    }
}

struct S
{
    union
    {
        int i;
        HasDestructor h;
    }
}

int d, p;
void main()
{
    {
        S s;
        s = s;
        assert(p == 0); // Should fail.
    }
    assert(d == 0); // Should fail.
}
