class D1
{
    int i = unknown;
}

enum x = new D1;

class D2
{
    int x;
    D2 d = { auto x = new D2(); return x; }();
}

enum y = new D2;
