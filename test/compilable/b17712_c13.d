// https://issues.dlang.org/show_bug.cgi?id=17712#c13

import std.datetime;
import std.typecons;
import std.variant;


Y a()
{
    Y n = Y(Y[].init);

    n.get!(X[]);
    return n;
}

struct X
{
    Y key;
}
struct Y
{
    Algebraic!(Y[]) value_;
    this(T)(T value)
    {
        value_ = value;
    }
    bool opEquals(T)(T rhs) const
    {
        static if(is(Unqual!T == Y))
        {
            return true;
        }
        else
        {
            return get!(T, No.x) == get!T;
        }
    }
    T get(T, Flag!"x" x = Yes.x)() const
    {
        return this[""].get!(T, x);
    }

    Y opIndex(T)(T index) const
    {
        const X[] pairs;
        if(pairs[0].key == index)
        {
            assert(0);
        }
        assert(0);
    }
}

void main(){}
