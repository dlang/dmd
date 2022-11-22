enum E { a, b }
static assert (() {
    E a = $a;
    E b = $b;
    return a == E.a && b == E.b;
} ());

enum XYZ { x, y, z }

XYZ intToXYZ(int i)
{
    switch(i)
    {
        case 1 : return $x;
        case 2 : return $y;
        case 3 : return $z;
        default:
    }

    return assert(0);
}

static assert(intToXYZ(2) == XYZ.y);

int XYZtoTint(XYZ xyz)
{
    switch(xyz)
    {
        case $x : return 1;
        case $y : return 2;
        case $z : return 3;
        default:
    }

    return assert(0);
}

static assert(XYZtoTint(XYZ.z) == 3);
