module imports.imp16085b;
import imports.imp16085 : S;

struct Fail
{
}

Fail functionAndFunction(ref S)
{
    return Fail();
}

Fail staticFunctionAndFunction(int)
{
    return Fail();
}

Fail functionAndTemplate(T)(T)
{
    return Fail();
}

Fail templateAndTemplate(T)(T)
{
    return Fail();
}
