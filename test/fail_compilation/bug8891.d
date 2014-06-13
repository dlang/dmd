/*
TEST_OUTPUT:
---
fail_compilation/bug8891.d(21): Error: cannot implicitly convert expression (10) of type int to S
---
*/

struct S
{
    int value = 10;
    S opCall(int n) // non-static
    {
        //printf("this.value = %d\n", this.value);    // prints garbage!
        S s;
        s.value = n;
        return s;
    }
}
void main()
{
    S s = 10;
}
