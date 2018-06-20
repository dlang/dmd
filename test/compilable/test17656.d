// https://issues.dlang.org/show_bug.cgi?id=17656

enum E
{
    AAA = S.BBB
}

struct S
{
    enum SZAQ = E.AAA;
    enum BBB = 8080;
}
