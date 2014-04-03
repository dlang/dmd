extern(C) int printf(const char*, ...);

/******************************************/
// 12078

class B12078(T)
{
    static assert(is(T : B12078!T), "not related");
}
class D12078 : B12078!D12078
{
}

interface X12078(T)
{
    static assert(is(T : X12078!T), "not related");
}
interface Y12078 : X12078!Y12078
{
}

void test12078()
{
    static assert(is(D12078 : B12078!D12078));
    static assert(is(Y12078 : X12078!Y12078));
}

/***************************************************/

int main()
{
    printf("Success\n");
    return 0;
}
