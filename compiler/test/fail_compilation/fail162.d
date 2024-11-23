/*
TEST_OUTPUT:
---
fail_compilation/fail162.d(31): Error: template `testHelper` is not callable using argument types `!()(string, string)`
    const char[] test = testHelper(A);
                                  ^
fail_compilation/fail162.d(16):        Candidate is: `testHelper(A...)()`
template testHelper(A ...)
^
fail_compilation/fail162.d(36): Error: template instance `fail162.test!("hello", "world")` error instantiating
    mixin(test!("hello", "world"));
          ^
---
*/

template testHelper(A ...)
{
    char[] testHelper()
    {
        char[] result;
        foreach (t; a)
        {
            result ~= "int " ~ t ~ ";\r\n";
        }
        return result;
    }
}

template test(A...)
{
    const char[] test = testHelper(A);
}

int main(char[][] args)
{
    mixin(test!("hello", "world"));
    return 0;
}
