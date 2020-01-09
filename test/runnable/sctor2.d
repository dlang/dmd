// PERMUTE_ARGS: -w -d -dw

/***************************************************/
// 15665

scope class C15665 (V)
{
    this () {}
}

void test15665()
{
    scope foo = new C15665!int;
}

void main()
{
    test15665();
}
