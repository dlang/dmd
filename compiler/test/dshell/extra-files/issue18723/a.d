module a;

// B's 100% threshold must not apply to this uncalled function in A.
int unused() { return 9; }

int twice(T)(T x)
{
    return x + x;
}

version (LocalCall)
    int fromA() { return twice(4); }
