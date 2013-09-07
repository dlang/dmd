enum E1
{
    alias a,
    b,
    c = 2,
    alias d = c,
    e,
}

static assert(E1.a == 0);
static assert(E1.b == 0);
static assert(E1.c == 2);
static assert(E1.d == 2);
static assert(E1.e == 3);

enum E2
{
    a,
    b,
    alias c = a,
    d,
    alias e = a,
    f,
}

static assert(E2.a == 0);
static assert(E2.b == 1);
static assert(E2.c == 0);
static assert(E2.d == 2);
static assert(E2.e == 0);
static assert(E2.f == 3);

void main() { }
