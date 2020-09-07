// https://issues.dlang.org/show_bug.cgi?id=19662
/**
PERMUTE_ARGS:
ARG_SETS:;-inline;-O -release;-O -release -inline;-O -release -inline -boundscheck=on;-O -release -inline -boundscheck=off
*/

import std.math : sin;

class Foo
{
    Quaternion!float rotation;
}

class ObjHolder
{
    Object[int] objs;
}

struct Quaternion(T)
{
    Vector!(T,4) vectorof;
    alias vectorof this;

    Vector!() opBinaryRight() ()     {
    }
        static Quaternion!(T) fromEulerAngles(Vector!(T,3) e)
        {
            Quaternion!(T) q;

            T sr = sin(e.x );
            q.w =  sr;
            q.x = sr;
            q.y =  sr;
            return q;
        }

}

struct Vector(T, int size)
{
static elements(string[] letters)     {
        string res;
        foreach (i; 0..size)
            res ~= "T " ~ letters[i] ~ "; ";
        return res;
    }
    union
    {
            struct { mixin(elements(["x", "y", "z", "w"])); }
    }
}

alias Vector3f = Vector!(float, 3);

void main()
{
    ObjHolder oh = new ObjHolder;
    Object o = new Object;
    oh.objs[0] = o;
    assert(oh.objs !is null);

    Foo f = new Foo;
    f.rotation = Quaternion!float.fromEulerAngles(Vector3f());
}
