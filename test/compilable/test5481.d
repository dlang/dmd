// REQUIRED_ARGS: -d -w

int n;
deprecated int a;
deprecated() int b;
deprecated("hard") int c;
deprecated("soft", soft) alias n d;
deprecated int e;
deprecated("through stc") immutable int f;
deprecated("through attribute") extern(C) int g;

class X
{
    deprecated("soft", soft) int y;
}

void main()
{
    auto x = new X();
    auto z = a + b + c + d + e + f + g + x.y;
}
