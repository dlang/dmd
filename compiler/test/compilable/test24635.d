// https://issues.dlang.org/show_bug.cgi?id=24635

struct S
{
    int opApply(int delegate(int) dg, int x = 0) => dg(x);
}

void main()
{
    foreach (int x; S()) { }
    foreach (x; S()) { }
}
