struct X
{
    static size_t opSlice(size_t a, size_t b)
    {
        return a + b;
    }

    static size_t opDollar()
    {
        return 42;
    }
}

static assert ( X[1..2]   == 3 );
static assert ( X[1..$]   == 43 );
static assert ( X[1..$-1] == 42 );

// array type syntax still has priority
static assert ( is(X[]) );
