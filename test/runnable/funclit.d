extern (C) int printf(const char*, ...);

/***************************************************/
// lambda syntax check

auto una(alias dg)(int n)
{
    return dg(n);
}
auto bin(alias dg)(int n, int m)
{
    return dg(n, m);
}
void test1()
{
    assert(una!(      a  => a*2 )(2) == 4);
    assert(una!( (    a) => a*2 )(2) == 4);
    assert(una!( (int a) => a*2 )(2) == 4);
    assert(una!(             (    a){ return a*2; } )(2) == 4);
    assert(una!( function    (    a){ return a*2; } )(2) == 4);
    assert(una!( function int(    a){ return a*2; } )(2) == 4);
    assert(una!( function    (int a){ return a*2; } )(2) == 4);
    assert(una!( function int(int a){ return a*2; } )(2) == 4);
    assert(una!( delegate    (    a){ return a*2; } )(2) == 4);
    assert(una!( delegate int(    a){ return a*2; } )(2) == 4);
    assert(una!( delegate    (int a){ return a*2; } )(2) == 4);
    assert(una!( delegate int(int a){ return a*2; } )(2) == 4);

    // partial parameter specialization syntax
    assert(bin!( (    a,     b) => a*2+b )(2,1) == 5);
    assert(bin!( (int a,     b) => a*2+b )(2,1) == 5);
    assert(bin!( (    a, int b) => a*2+b )(2,1) == 5);
    assert(bin!( (int a, int b) => a*2+b )(2,1) == 5);
    assert(bin!(             (    a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!(             (int a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!(             (    a, int b){ return a*2+b; } )(2,1) == 5);
    assert(bin!(             (int a, int b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( function    (    a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( function    (int a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( function    (    a, int b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( function    (int a, int b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( function int(    a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( function int(int a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( function int(    a, int b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( function int(int a, int b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( delegate    (    a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( delegate    (int a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( delegate    (    a, int b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( delegate    (int a, int b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( delegate int(    a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( delegate int(int a,     b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( delegate int(    a, int b){ return a*2+b; } )(2,1) == 5);
    assert(bin!( delegate int(int a, int b){ return a*2+b; } )(2,1) == 5);
}

/***************************************************/

int main()
{
    test1();

    printf("Success\n");
    return 0;
}
