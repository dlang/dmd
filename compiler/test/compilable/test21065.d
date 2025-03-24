// https://github.com/dlang/dmd/issues/21065

extern(C++) class CXX
{
    int method();
    ubyte[4] not_multiple_of_8;
}
static assert(__traits(classInstanceAlignment, CXX) == 8);
static assert(__traits(classInstanceSize, CXX) == 16);

////////////////////////////////////////////

extern(C++) class CXX2 : CXX
{
    ubyte[4] also_not_multiple;
}
version (Posix) static assert(__traits(classInstanceAlignment, CXX2) == 8);
version (Posix) static assert(__traits(classInstanceSize, CXX2) == 16);

////////////////////////////////////////////

extern(D) class D
{
    ubyte[4] not_multiple_of_8;
}
static assert(__traits(classInstanceAlignment, D) == 8);
static assert(__traits(classInstanceSize, D) == 24);

////////////////////////////////////////////

extern(D) class D2 : D
{
    ubyte[4] also_not_multiple;
}
static assert(__traits(classInstanceAlignment, D) == 8);
static assert(__traits(classInstanceSize, D) == 24);
