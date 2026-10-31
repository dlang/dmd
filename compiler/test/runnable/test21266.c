/* https://issues.dlang.org/show_bug.cgi?id=21266
 */

// An unreferenced __forceinline function must not generate code, even if
// its body calls something that is never defined - matching real C
// semantics for an unused inline definition. Previously ImportC emitted
// code for it unconditionally, which broke linking.

void i_do_not_exist(void);

__forceinline void i_am_not_called(void)
{
    i_do_not_exist();
}

// A __forceinline function that *is* referenced must still get real code.

int helper(int x);

__forceinline int i_am_called(int x)
{
    return helper(x) + 1;
}

int helper(int x)
{
    return x * 2;
}

int main()
{
    if (i_am_called(5) != 11)
        return 1;
    return 0;
}
