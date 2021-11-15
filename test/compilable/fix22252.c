
/* Test conversion of parameter types:
 *    array of T => pointer to T
 *    function => pointer to function
 */

int test1(int a[])
{
    return *a;
}

int test2(int a[3])
{
    return *a;
}

int test3(int fp())
{
    return (*fp)();
}
