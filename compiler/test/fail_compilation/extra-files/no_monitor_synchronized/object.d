module object;

alias size_t = typeof(int.sizeof);

class Object {
}
class TypeInfo {}
class TypeInfo_Class : TypeInfo
{
    version(D_LP64) { ubyte[136+24] _x; } else { ubyte[68+20] _x; }
}
