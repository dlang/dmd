module test8716;

package int gf() { return 1; }
static assert(gf() == 1);

class C
{
package:
    enum e = 1;
    immutable static int si = 1;
    static int sf() { return 1; }
    immutable int i = 1;
    int f() const { return 1; }
}

static assert(C.e == 1);
static assert(C.si == 1);
static assert(C.sf() == 1);
static assert(C.i == 1);
static assert(C.init.e == 1);
static assert(C.init.si == 1);
static assert(C.sf() == 1);
static assert(C.init.i == 1);

static if(C.e != 1) { static assert(0); }
static if(C.si != 1) { static assert(0); }
static if(C.sf() != 1) { static assert(0); }
static if(C.i != 1) { static assert(0); }
static if(C.init.e != 1) { static assert(0); }
static if(C.init.si != 1) { static assert(0); }
static if(C.sf() != 1) { static assert(0); }
static if(C.init.i != 1) { static assert(0); }

void main() { }
