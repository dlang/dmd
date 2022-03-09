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
