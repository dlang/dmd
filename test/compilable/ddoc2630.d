// PERMUTE_ARGS:
// REQUIRED_ARGS: -D -Ddtest_results/compilable -o-
// POST_SCRIPT: compilable/extra-files/ddocAny-postscript.sh 2630

module ddoc2630;

/**
two examples
*/
int add(int a, int b) { return a + b; }

/// empty
unittest
{
}

/// test unittest
unittest
{
    assert(add(1, 2) == 3);
    assert(add(5, 5) == 10);
}

///
unittest
{
    assert(add(2, 2) + add(2, 2) == 8);
}

/// one example
void test1() { }

/// documented
unittest
{
    test1();
}

/// undocumented
private unittest
{
    test1();
}

/// no examples
void test2() { }

/// undocumented
private unittest
{
    test2();
}

/// undocumented
unittest
{
    test2();
}

void main() { }
