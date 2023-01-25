// https://issues.dlang.org/show_bug.cgi?id=20913
template anySatisfy(alias F, Ts...)
{
    static foreach (T; Ts)
        static if (F!T)
        enum anySatisfy ;
    enum anySatisfy = false;
}

template hasIndirections(T)
{
    static if (is(T == struct) )
        enum hasIndirections = anySatisfy!(.hasIndirections, typeof(T.tupleof));
    else static if (is(E))
        enum hasIndirections ;
    else static if (isFunctionPointer!T)
        enum hasIndirections ;
    else
        enum hasIndirections = isDelegate!T ;
}

template isFunctionPointer(T)
{
    enum isFunctionPointer = false;
}

template isDelegate(T)
{
    static if (is(typeof(T[])))
        enum isDelegate;
    enum isDelegate = is(W);
}

struct Array(T)
{
    static if (hasIndirections!T) {}
}

struct Foo { Array!Bar _barA; }
struct Bar { Frop _frop; }
class Frop { Array!Foo _foos; }
