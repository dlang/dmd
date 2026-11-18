module a;

// B's 100% threshold must not apply to this uncalled function in A.
int unused() { return 9; }

int twice(T)(T x)
{
    return x + x;
}

version (LocalCall)
{
    // This deferred archive member has a static constructor but no coverage counters.
    template State()
    {
        static int value = 4;
        static this() {}
    }

    int fromA() { return twice(State!().value); }
}
