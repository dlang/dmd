// REQUIRED_ARGS: -O -release -inline
// https://issues.dlang.org/show_bug.cgi?id=19662

import core.math : sin;

class ObjHolder
{
    Quaternion rotation;
    Object[int] objs;
}

struct Quaternion
{
    float x, y, z, w;

    static Quaternion fromEulerAngles()
    {
        Quaternion q;

        float sr = sin(1.0f);
        q.w = sr;
        q.x = sr;
        q.y = sr;
        return q;
    }
}

ObjHolder create()
{
    ObjHolder oh = new ObjHolder;

    Object o = new Object;
    oh.objs[0] = o;
    oh.rotation = Quaternion.fromEulerAngles();

    return oh;
}

void main()
{
    ObjHolder oh = create();
    if (!oh.objs[0]) assert(false);
}
