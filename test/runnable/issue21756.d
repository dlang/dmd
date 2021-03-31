module issue21756;

auto test1() @nogc
{
    return  cast(immutable)['a', 'b', 'c'];
}

auto test2() @nogc
{
    return cast(immutable)[1, 2, 3];
}

struct S
{
    int a,b,c;
}

auto test3() @nogc
{
    return cast(immutable)[S(1,2,3), S(1,2,3)];
}

void main() @nogc
{
    assert(test1() == "abc");
    assert(test2()[2] == 3);
    assert(test3()[0] == test3()[1]);
}
