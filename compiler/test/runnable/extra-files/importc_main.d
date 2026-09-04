
import core.stdc.stdio;
import importc_test;

int main()
{
    auto rc = someCodeInC(3, 4);
    printf("Result of someCodeInC(3,4) = %d\n", rc);
    assert( rc == 7, "Wrong result");
    return 0;
}
