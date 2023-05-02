// https://issues.dlang.org/show_bug.cgi?id=23874
// REQUIRED_ARGS: -profile=gc

string myToString()
{
    return "";
}

enum x = myToString ~ "";
