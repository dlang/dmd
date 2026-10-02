// https://issues.dlang.org/show_bug.cgi?id=23925

enum E
{
    Value
}

struct S
{
    const(int) get() => 10;
}

alias IntFunc = int delegate();

void matchEnum(IntFunc[E]) {}
void matchInt(IntFunc[int]) {}

void main()
{
    S s;
    matchEnum([E.Value: () => s.get()]);
    matchInt([0: () => s.get()]);
}
