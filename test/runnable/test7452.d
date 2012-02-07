import core.stdc.stdio : printf;

//------------------------------------------------------------------------------

T enforce7452(T, string file = __FILE__, size_t line = __LINE__)
    (T value, lazy const(char)[] msg = null) @safe pure
{
    if (!value)
        throw new Exception(msg ? msg.idup : "Enforcement failed", file, line);
    return value;
}

int f7452()(int x)
{
   enforce7452(x > 0);
   return x;
}
void g7452() @safe pure
{
   assert(4 == f7452(4));
}

//------------------------------------------------------------------------------

void e7452b(int, lazy int) pure nothrow @safe {}
int f7452b()(int x)
{
   e7452b(x, 0);
   return x;
}
void g7452b() pure nothrow @safe
{
   assert(4 == f7452b(4));
}

//------------------------------------------------------------------------------

int f7452c()(int x)
{
   auto y = function int() { return 0; };
   return x;
}
void g7452c() pure nothrow @safe
{
   assert(4 == f7452c(4));
}

//------------------------------------------------------------------------------

int main()
{
    g7452();
    g7452b();
    g7452c();

    printf("Success\n");
    return 0;
}


