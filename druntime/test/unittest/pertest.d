module pertest;

import core.stdc.stdio : FILE, fprintf, stderr;

unittest
{
}

unittest
{
    version (FailingTest) assert(false, "boom");
}

unittest
{
    // Shows whether the tests after a failing one still run.
    fprintf(cast(FILE*) stderr, "after\n");
}

void main()
{
    fprintf(cast(FILE*) stderr, "main\n");
}

unittest
{
    version (FailingTest) throw new Exception("thrown");
}
