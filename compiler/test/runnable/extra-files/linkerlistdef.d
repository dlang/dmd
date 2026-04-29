module linkerlistdef;
import core.attribute;

__linkerlist!int myInts;
__linkerlist!(int[3]) my3Ints;
__linkerlist!Object myObjects;
__linkerlist!I myInterfaces;
__linkerlist!S myStructs1;
__linkerlist!(S*) myStructs2;
__linkerlist!string myStrings;

struct S {
    int val;
}

interface I {
}

class CI : I {
}

static assert(() { myInts ~= 15; return true; }());
static assert(() { my3Ints ~= [15, 16, 17]; return true; }());
static assert(() { myObjects ~= new Object; return true; }());
static assert(() { myInterfaces ~= new CI; return true; }());
static assert(() { myStructs1 ~= S(18); return true; }());
static assert(() { myStructs2 ~= new S(19); return true; }());
static assert(() { myStrings ~= __FUNCTION__; return true; }());
