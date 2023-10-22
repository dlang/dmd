/*
TEST_OUTPUT:
---
AliasSeq!("betty %s", 73)
AliasSeq!("betty %d", 73)
AliasSeq!("betty %d", 74)
---
*/
import core.stdc.stdio;

int main()
{
    enum x = 73;
    pragma(msg, i"betty $x");
    pragma(msg, i"betty ${%d}x");
    pragma(msg, i"betty ${%d}(x + 1)");

    string betty = "betty";
    printf(i"hello $(betty.ptr)\n");

    int aa = 5;
    int bb = 10;
    string s = "ate";
    printf(i"I $(s.ptr) ${%d}aa apples and ${%d}bb bananas totalling ${%d}(aa + bb) fruits! $$.\n");

    return 0;
}
