// PERMUTE_ARGS:
//
// CTFE constructor / copy-constructor tests.
// The `^^` (pow) parts that used to live here are in runnable/pow.d.

int magicVariable()
{
    if (__ctfe)
        return 3;

    shared int var = 2;
    return var;
}

static assert(magicVariable()==3);

// https://issues.dlang.org/show_bug.cgi?id=3535
struct StructWithCtor
{
    this(int _n) {
        n = _n; x = 5;
    }
    this(int _n, float _x) {
        n = _n; x = _x;
    }
    int n;
    float x;
}

enum A = StructWithCtor(1);
enum B = StructWithCtor(7, 2.3);

static assert(A.n == 1);
static assert(A.x == 5.0);
static assert(B.n == 7);
static assert(B.x == 2.3);

// Test copy constructors
struct CopyTest {
   double x;
   this(double a) { x = a * 10.0;}
   this(this) {  x+=2.0;}
}

struct CopyTest2
{
   int x; int x1; int x2; int x3;
   this(int a) { x = a * 2; x1 = 3;}
   this(this) {  x1+=17;}
}


const CopyTest z = CopyTest(5.3);
/+
// TODO: This is not yet supported. But it
// generates an error message instead of wrong-code.
const CopyTest w = z;
static assert(z.x==55.0);
+/

int copytest1()
{
   CopyTest z = CopyTest(3.4);
   CopyTest w = z;
   assert(w.x == 36.0);
   CopyTest2 q = CopyTest2(7);
   CopyTest2 q2 = q;
   CopyTest2 q3 = q2;
   assert(q3.x1 == 37);

  return 123;
}
static assert(copytest1()==123);

// This must not cause a segfault
alias int FILTH;
struct Filth
{
     struct Impl
    {
        FILTH * handle = null;
        this(FILTH* h, uint r, string n)
        {
            handle = h;
        }
    }
    Impl * p;

    this(string name, in char[] stdioOpenmode = "rb")
    {
    }

    ~this()
    {
        if (!p) return;
    }

    this(this)
    {
        if (!p) return;
    }
    }
    struct InputByChar
    {
        private Filth _f;

        this(Filth f)
        {
            _f = f;
        }
}

/************************************/

void main()
{
    assert(!__ctfe);
    assert(magicVariable()==2);
}
