const(char)[] errMsg;
import std.functional();
uint testLazyP(lazy uint p1, lazy const(char)[] msg = null)
{
    if (p1)
    {
        errMsg = null;
        return p1;
    }
    else 
    {
        errMsg = msg;
        return 0;
    }
}

void main()
{
    testLazyP(uint.max, "err");
    assert(errMsg == null);
}
