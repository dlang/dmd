/*
TEST_OUTPUT:
---
---
*/

struct HasDestructor
{
    ~this()
    {
        assert(0);
    }
    this(this)
    {
        assert(0);
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

struct S2
{
    union
    {
        align(1)
        {
            int i;
            HasDestructor h;
        }
    }
}

void main()
{
    {
        S s;
        s = s;
    }

    {
        S2 s2;
        s2 = s2;
    }
}
