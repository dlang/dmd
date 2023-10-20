// https://issues.dlang.org/show_bug.cgi?id=22842

/*******************************/

typedef int (myfunc)();
myfunc fun;

/*******************************/

int town();
typedef int (funky)();
funky town;

/*******************************/

typedef int (mudd)();

static mudd ville;

int job()
{
    return ville();
}

int ville() // inherits "static" from declaration.
{
    return 0;
}

/*******************************/

typedef int (skyy)();
void high()
{
    skyy asdf;
}

/*******************************/

void low()
{
    typedef int (down)();
}

typedef int down;
down dd;
int low2()
{
    dd = 1;
}

/***********************************************************************/

// https://issues.dlang.org/show_bug.cgi?id=22876

int mint1()
{
    int a = 0;
    // dmd gives 1, other compilers -1
    // bug disappears if the parentheses around (a) are removed
    return - (a) - 1;
}

_Static_assert(mint1() == -1, "1");

int mint2()
{
    int *a, *b;
    // Error: incompatible types for `(a) - (cast(char*)b)`: `int*` and `char*`
    // works if the parentheses around (a) are removed
    long diff = (char*)(a) - (char*)b;
}

void mint3()
{
    int *p;
    // Error: `p` is not of integral type, it is a `int*`
    // Error: `cast(int*)1` is not of integral type, it is a `int*`
    // works if parentheses around (p) are removed
    unsigned x = (unsigned)(p) & 1;
}
