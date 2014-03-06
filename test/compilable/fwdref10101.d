// PERMUTE_ARGS:

int front(int);

mixin template reflectRange()
{
    static if ( is( typeof(this.front) ) )
    {
        int x;
    }
}

struct S(R)
{
    R r_;

    typeof(r_.front) front() @property { return r_.front; }

    mixin reflectRange;
}

void main()
{
    S!(int) s;
}
