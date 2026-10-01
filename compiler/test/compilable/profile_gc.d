// REQUIRED_ARGS: -profile=gc

// https://issues.dlang.org/show_bug.cgi?id=23874
string myToString()
{
    return "";
}

enum x = myToString ~ "";
immutable x2 = myToString ~ "";

// https://github.com/dlang/dmd/issues/22842
struct UpaTester{}
UpaTester[] test(){return [UpaTester()];}
