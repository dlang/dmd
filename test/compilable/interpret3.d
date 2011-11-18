// PERMUTE_ARGS: -inline

template compiles(int T)
{
   bool compiles = true;
}

/**************************************************
    3901 Arbitrary struct assignment, ref return
**************************************************/

struct ArrayRet{
   int x;
}

int arrayRetTest(int z)
{
  ArrayRet[6] w;
  int q = (w[3].x = z);
  return q;
}

static assert(arrayRetTest(51)==51);

// Bugzilla 3842 -- must not segfault
int ice3842(int z)
{
   ArrayRet w;
   return arrayRetTest((*(&w)).x);
}

static assert(true || is(typeof(compiles!(ice3842(51)))));


int arrayret2(){

  int [5] a;
  int [3] b;
  b[] = a[1..$-1] = 5;
  return b[1];
}
static assert(arrayret2()==5);

struct DotVarTest
{
   ArrayRet z;
}

struct DotVarTest2
{
   ArrayRet z;
   DotVarTest p;
}

int dotvar1()
{
    DotVarTest w;
    w.z.x = 3;
    return w.z.x;
}

int dotvar2()
{
    DotVarTest2[4] m;
    m[2].z.x = 3;
    m[1].p.z.x = 5;
    return m[2].z.x + 7;
}

static assert(dotvar1()==3);
static assert(dotvar2()==10);


struct RetRefStruct{
   int x;
   char c;
}

// Return value reference tests, for D2 only.

ref RetRefStruct reffunc1(ref RetRefStruct a)
{
int y = a.x;
return a;
}


ref RetRefStruct reffunc2(ref RetRefStruct a)
{
   RetRefStruct z = a;
   return reffunc1(a);
}

ref int reffunc7(ref RetRefStruct aa)
{
   return reffunc1(aa).x;
}

ref int reffunc3(ref int a)
{
    return a;
}

struct RefTestStruct
{
  RetRefStruct r;

  ref RefTestStruct reffunc4(ref RetRefStruct[3] a)
  {
    return this;
  }

  ref int reffunc6()
  {
    return this.r.x;
  }
}

ref RetRefStruct reffunc5(ref RetRefStruct[3] a)
{
   int t = 1;
   for (int i=0; i<10; ++i)
   { if (i==7)  ++t;}
    return a[reffunc3(t)];
}

int retRefTest1()
{
    RetRefStruct b = RetRefStruct(0,'a');
    reffunc1(b).x =3;
    return b.x-1;
}

int retRefTest2()
{
    RetRefStruct b = RetRefStruct(0,'a');
    reffunc2(b).x =3;
    RetRefStruct[3] z;
    RefTestStruct w;
    w.reffunc4(z).reffunc4(z).r.x = 4;
    assert(w.r.x == 4);
    w.reffunc6() = 218;
    assert(w.r.x == 218);
    z[2].x = 3;
    int q=4;
    int u = reffunc5(z).x + reffunc3(q);
    assert(u==7);
    reffunc5(z).x += 7;
    assert(z[2].x == 10);
    RetRefStruct m = RetRefStruct(7, 'c');
    m.x = 6;
    reffunc7(m)+=3;
    assert(m.x==9);
    return b.x-1;
}

int retRefTest3()
{
    RetRefStruct b = RetRefStruct(0,'a');
    auto deleg = function (RetRefStruct a){ return a;};
    typeof(deleg)[3] z;
    z[] = deleg;
    auto y = deleg(b).x + 27;
    b.x = 5;
    assert(y == 27);
    y = z[1](b).x + 22;
    return y - 1;
}

int retRefTest4()
{
    RetRefStruct b = RetRefStruct(0,'a');
    reffunc3(b.x) = 218;
    assert(b.x == 218);
    return b.x;
}

static assert(retRefTest1()==2);
static assert(retRefTest2()==2);
static assert(retRefTest3()==26);
static assert(retRefTest4()==218);

/**************************************************
    Bug 4389
**************************************************/

int bug4389()
{
    string s;
    dchar c = '\u2348';
    s ~= c;
    assert(s.length==3);
    dchar d = 'D';
    s ~= d;
    assert(s.length==4);
    s = "";
    s ~= c;
    assert(s.length==3);
    s ~= d;
    assert(s.length==4);
    string z;
    wchar w = '\u0300';
    z ~= w;
    assert(z.length==2);
    z = "";
    z ~= w;
    assert(z.length==2);
    return 1;
}

static assert(bug4389());

// ICE(constfold.c)
int ice4389()
{
    string s;
    dchar c = '\u2348';
    s ~= c;
    s = s ~ "xxx";
   return 1;
}

static assert(ice4389());

// ICE(expression.c)
string ice4390()
{
    string s;
    dchar c = '`';
    s ~= c;
    s ~= c;
   return s;
}

static assert(mixin(ice4390()) == ``);

// bug 5248 (D1 + D2)
struct Leaf5248 {
    string Compile_not_ovloaded() {
        return "expression";
    }
};
struct Matrix5248 {
    Leaf5248 Right;

    string Compile() {
        return Right.Compile_not_ovloaded();
    }
};

static assert(Matrix5248().Compile());

/**************************************************
    4837   >>>=
**************************************************/

bool bug4837()
{
    ushort x = 0x89AB;
    x >>>= 4;
    assert(x == 0x89A);
    byte y = 0x7C;
    y >>>= 2;
    assert(y == 0x1F);
    return true;
}

static assert(bug4837());

/**************************************************
   6972 ICE with cast()cast()assign
**************************************************/

int bug6972()
{
    ubyte n = 6;
    n /= 2u;
    return n;
}
static assert(bug6972()==3);

/**************************************************
    Bug 6164
**************************************************/

size_t bug6164(){
    int[] ctfe2(int n){
        int[] r=[];
        if(n!=0) r~=[1] ~ ctfe2(n-1);
        return r;
    }
    return ctfe2(2).length;
}
static assert(bug6164()==2);

/**************************************************
    Interpreter code coverage tests
**************************************************/

int cov1(int a)
{
   a %= 15382;
   a /= 5;
   a = ~ a;
   bool c = (a==0);
   bool b = true && c;
   assert(b==0);
   b = false && c;
   assert(b==0);
   b = false || c;
   assert(b==0);
   a ^= 0x45349;
   a = ~ a;
   a &= 0xFF3F;
   a >>>= 1;
   a = a ^ 0x7393;
   a = a >> 1;
   a = a >>> 1;
   a = a | 0x010101;
   return a;
}
static assert(cov1(534564) == 71589);

int cov2()
{
    int i = 0;
    do{
        goto DOLABEL;
    DOLABEL:
        if (i!=0) {
            goto IFLABEL;
    IFLABEL:
            switch(i) {
            case 3:
                break;
            case 6:
                goto SWITCHLABEL;
    SWITCHLABEL:
                i = 27;
                goto case 3;
	     default: assert(0);
            }
            return i;
        }
        i = 6;
    } while(true);
    return 88; // unreachable
}

static assert(cov2()==27);

template CovTuple(T...)
{
  alias T CovTuple;
}

alias CovTuple!(int, long) TCov3;

int cov3(TCov3 t)
{
    TCov3 s;
    s = t;
    assert(s[0] == 1);
    assert(s[1] == 2);
    return 7;
}

static assert(cov3(1, 2) == 7);

int badassert1(int z)
{
   assert(z == 5, "xyz");
   return 1;
}

size_t badslice1(int[] z)
{
  return z[0..3].length;
}

size_t badslice2(int[] z)
{
  return z[0..badassert1(1)].length;
}

size_t badslice3(int[] z)
{
  return z[badassert1(1)..2].length;
}

static assert(!is(typeof(compiles!(badassert1(67)))));
static assert(is(typeof(compiles!(badassert1(5)))));
static assert(!is(typeof(compiles!(badslice1([1,2])))));
static assert(!is(typeof(compiles!(badslice2([1,2])))));
static assert(!is(typeof(compiles!(badslice3([1,2,3])))));

/*******************************************/

size_t bug5524(int x, int[] more...)
{
    int[0] zz;
    assert(zz.length==0);
    return 7 + more.length + x;
}

static assert(bug5524(3) == 10);


// 5722

static assert( ("" ~ "\&copy;"[0]).length == 1 );
const char[] null5722 = null;
static assert( (null5722 ~ "\&copy;"[0]).length == 1 );
static assert( ("\&copy;"[0] ~ null5722).length == 1 );

/*******************************************
 * Tests for CTFE Array support.
 * Including bugs 1330, 3801, 3835, 4050,
 * 4051, 5147, and major functionality
 *******************************************/

char[] bug1330StringIndex()
{
    char [] blah = "foo".dup;
    assert(blah == "foo");
    char [] s = blah[0..2];
    blah[0] = 'h';
    assert(s== "ho");
    s[0] = 'm';
    return blah;
}

static assert(bug1330StringIndex()=="moo");
static assert(bug1330StringIndex()=="moo"); // check we haven't clobbered any string literals

int[] bug1330ArrayIndex()
{
    int [] blah = [1,2,3];
    int [] s = blah;
    s = blah[0..2];
    int z = blah[0] = 6;
    assert(z==6);
    assert(blah[0]==6);
    assert(s[0]==6);
    assert(s== [6, 2]);
    s[1] = 4;
    assert(z==6);
    return blah;
}

static assert(bug1330ArrayIndex()==[6,4,3]);
static assert(bug1330ArrayIndex()==[6,4,3]); // check we haven't clobbered any literals

char[] bug1330StringSliceAssign()
{
    char [] blah = "food".dup;
    assert(blah == "food");
    char [] s = blah[1..4];
    blah[0..2] = "hc";
    assert(s== "cod");
    s[0..2] = ['a', 'b'];   // Mix string + array literal
    assert(blah == "habd");
    s[0..2] = "mq";
    return blah;
}

static assert(bug1330StringSliceAssign()=="hmqd");
static assert(bug1330StringSliceAssign()=="hmqd");

int[] bug1330ArraySliceAssign()
{
    int [] blah = [1,2,3,4];
    int [] s = blah[1..4];
    blah[0..2] = [7, 9];
    assert(s == [9,3,4]);
    s[0..2] = [8, 15];
    return blah;
}

static assert(bug1330ArraySliceAssign()==[7, 8, 15, 4]);

int[] bug1330ArrayBlockAssign()
{
    int [] blah = [1,2,3,4,5];
    int [] s = blah[1..4];
    blah[0..2] = 17;
    assert(s == [17,3,4]);
    s[0..2] = 9;
    return blah;
}

static assert(bug1330ArrayBlockAssign()==[17, 9, 9, 4, 5]);

char[] bug1330StringBlockAssign()
{
    char [] blah = "abcde".dup;
    char [] s = blah[1..4];
    blah[0..2] = 'x';
    assert(s == "xcd");
    s[0..2] = 'y';
    return blah;
}

static assert(bug1330StringBlockAssign() == "xyyde");

int assignAA(int x) {
    int[int] aa;
    int[int] cc = aa;
    assert(cc.values.length==0);
    assert(cc.keys.length==0);
    aa[1] = 2;
    aa[x] = 6;
    int[int] bb = aa;
    assert(bb.keys.length==2);
    assert(cc.keys.length==0); // cc is not affected to aa, because it is null
    aa[500] = 65;
    assert(bb.keys.length==3); // but bb is affected by changes to aa
    return aa[1] + aa[x];
}
static assert(assignAA(12) == 8);

template Compileable(int z) { bool OK;}

int arraybounds(int j, int k)
{
    int [] xxx = [1, 2, 3, 4, 5];
    int [] s = xxx[1..$];
    s = s[j..k]; // slice of slice
    return s[$-1];
}

int arraybounds2(int j, int k)
{
    int [] xxx = [1, 2, 3, 4, 5];
    int [] s = xxx[j..k]; // direct slice
    return 1;
}
static assert( !is(typeof(Compileable!(arraybounds(1, 14)))));
static assert( !is(typeof(Compileable!(arraybounds(15, 3)))));
static assert( arraybounds(2,4) == 5);
static assert( !is(typeof(Compileable!(arraybounds2(1, 14)))));
static assert( !is(typeof(Compileable!(arraybounds2(15, 3)))));
static assert( arraybounds2(2,4) == 1);

int bug5147a() {
    int[1][2] a = 37;
    return a[0][0];
}

static assert(bug5147a()==37);

int bug5147b() {
    int[4][2][3][17] a = 37;
    return a[0][0][0][0];
}

static assert(bug5147b()==37);

int setlen()
{
    int[][] zzz;
    zzz.length = 2;
    zzz[0].length = 10;
    assert(zzz.length == 2);
    assert(zzz[0].length==10);
    assert(zzz[1].length==0);
    return 2;
}

static assert(setlen()==2);

int[1][1] bug5147() {
    int[1][1] a = 1;
    return a;
}
static assert(bug5147() == [[1]]);
enum int[1][1] enum5147 = bug5147();
static assert(enum5147 == [[1]]);
immutable int[1][1] bug5147imm = bug5147();


// Index referencing
int[2][2] indexref() {
    int[2][2] a = 2;
    a[0]=7;

    int[][] b = [null, null];
    b[0..$] = a[0][0..2];
    assert(b[0][0]==7);
    assert(b[0][1]==7);
    int [] w;
    w = a[0];
    assert(w[0]==7);
    w[0..$] = 5;
    assert(a[0]!=[7,7]);
    assert(a[0]==[5,5]);
    assert(b[0] == [5,5]);
    return a;
}
int[2][2] indexref2() {
    int[2][2] a = 2;
    a[0]=7;

    int[][2] b = null;
    b[0..$] = a[0];
    assert(b[0][0]==7);
    assert(b[0][1]==7);
    assert(b == [[7,7], [7,7]]);
    int [] w;
    w = a[0];
    assert(w[0]==7);
    w[0..$] = 5;
    assert(a[0]!=[7,7]);
    assert(a[0]==[5,5]);
    assert(b[0] == [5,5]);
    return a;
}
int[2][2] indexref3() {
    int[2][2] a = 2;
    a[0]=7;

    int[][2] b = [null, null];
    b[0..$] = a[0];
    assert(b[0][0]==7);
    assert(b[0][1]==7);
    int [] w;
    w = a[0];
    assert(w[0]==7);
    w[0..$] = 5;
    assert(a[0]!=[7,7]);
    assert(a[0]==[5,5]);
    assert(b[0] == [5,5]);
    return a;
}
int[2][2] indexref4() {
    int[2][2] a = 2;
    a[0]=7;

    int[][2] b =[[1,2,3],[1,2,3]]; // wrong code
    b[0] = a[0];
    assert(b[0][0]==7);
    assert(b[0][1]==7);
    int [] w;
    w = a[0]; //[0..$];
    assert(w[0]==7);
    w[0..$] = 5;
    assert(a[0]!=[7,7]);
    assert(a[0]==[5,5]);
    assert(b[0] == [5,5]);
    return a;
}

static assert(indexref() == [[5,5], [2,2]]);
static assert(indexref2() == [[5,5], [2,2]]);
static assert(indexref3() == [[5,5], [2,2]]);
static assert(indexref4() == [[5,5], [2,2]]);

int staticdynamic() {
    int[2][1] a = 2;
    assert( a == [[2,2]]);

    int[][1] b = a[0][0..1];
    assert(b[0] == [2]);
    auto k = b[0];
    auto m = a[0][0..1];
    assert(k == [2]);
    assert(m == k);
    return 0;
}
static assert(staticdynamic() == 0);

int[] crashing()
{
    int[12] cra;
    return (cra[2..$]=3);
}
static assert(crashing()[9]==3);

int chainassign()
{
    int[4] x = 6;
    int[] y = new int[4];
    auto k = (y[] = (x[] = 2));
    return k[0];
}
static assert(chainassign()==2);

// index assignment
struct S3801 {
char c;
  int[3] arr;

  this(int x, int y){
    c = 'x';
    arr[0] = x;
    arr[1] = y;
  }
}

int bug3801()
{
    S3801 xxx = S3801(17, 67);
    int[] w = xxx.arr;
    xxx.arr[1] = 89;
    assert(xxx.arr[0]==17);
    assert(w[1] == 89);
    assert(w == [17, 89, 0]);
    return xxx.arr[1];
}

enum : S3801 { bug3801e = S3801(17, 18) }
static assert(bug3801e.arr == [17, 18, 0]);
immutable S3801 bug3801u = S3801(17, 18);
static assert(bug3801u.arr == [17, 18, 0]);
static assert(bug3801()==89);

int bug3835() {
    int[4] arr;
    arr[]=19;
    arr[0] = 4;
    int kk;
    foreach (ref el; arr)
    {
        el += 10;
        kk = el;
    }
    assert(arr[2]==29);
    arr[0]+=3;
    return arr[0];
}
static assert(bug3835() == 17);

auto bug5852(const(string) s) {
    string [] r;
    r ~= s;
    assert(r.length == 1);
    return r[0].length;
}

static assert(bug5852("abc")==3);

/*******************************************
    Set array length
*******************************************/

static assert(
{
    struct W{ int [] z;}
    W w;
    w.z.length = 2;
    assert(w.z.length == 2);
    w.z.length = 6;
    assert(w.z.length == 6);
    return true;
}());

/*******************************************
             Bug 5671
*******************************************/

static assert( ['a', 'b'] ~ "c" == "abc" );

/*******************************************
        Bug 6159
*******************************************/

struct A6159 {}

static assert({ return A6159.init is A6159.init;}());
static assert({ return [1] is [1];}());

/*******************************************
        Bug 5685
*******************************************/

string bug5685() {
  return "xxx";
}
struct Bug5865 {
    void test1(){
        enum file2 = (bug5685())[0..$]  ;
    }
}

/*******************************************
    6235 - Regression ICE on $ in template
*******************************************/

struct Bug6235(R) {
    enum XXX = is(typeof(R.init[0..$]) : const ubyte[]);
}

Bug6235!(ubyte[]) bug6235;

/*******************************************
        Bug 5840
*******************************************/

struct Bug5840 {
    string g;
    int w;
}

int bug5840(int u)
{   // check for clobbering
    Bug5840 x = void;
    x.w = 4;
    x.g = "3gs";
    if (u==1) bug5840(2);
    if (u==2) {
        x.g = "abc";
        x.w = 3465;
    } else {
        assert(x.g == "3gs");
        assert(x.w == 4);
    }
    return 56;
}
static assert(bug5840(1)==56);

/*******************************************
    std.datetime ICE (30 April 2011)
*******************************************/

struct TimeOfDayZ
{
public:
    this(int hour) { }
    invariant() { }
}
const testTODsThrownZ = TimeOfDayZ(0);

/*******************************************
        Bug 5954
*******************************************/

struct Bug5954 {
    int x;
    this(int xx) {
        this.x = xx;
    }
}
void bug5954() {
    enum f = Bug5954(10);
    static assert(f.x == 10);
}


/*******************************************
        Bug 5972
*******************************************/

int bug5972()
{
  char [] z = "abc".dup;
  char[] [] a = [null, null];
  a[0]  = z[0..2];
  char[] b = a[0];
  assert(b == "ab");
  a[0][1] = 'q';
  assert( a[0] == "aq");
  assert(b == "aq");
  assert(b[1]=='q');
  a[0][0..$-1][0..$] = a[0][0..$-1][0..$];
  return 56;
}
static assert(bug5972()==56);

/*******************************************
    2.053beta [CTFE]ICE 'global errors'
*******************************************/

int wconcat(wstring replace)
{
  wstring value;
  value  = "A"w;
  value = value ~ replace;
  return 1;
}
static assert(wconcat("X"w));

/*******************************************
    Bug 4001: A Space Oddity
*******************************************/

int space() { return 4001; }

void oddity4001(int q)
{
    const int bowie = space();
    static assert(space() == 4001);
    static assert(bowie == 4001);
}

/*******************************************
    Bug 3779
*******************************************/

static const bug3779 = ["123"][0][$-1];


/*******************************************
    non-Cow struct literals
*******************************************/

struct Zadok
{
    int [3] z;
    char [4] s = void;
    ref int[] fog(ref int [] q) { return q; }
    int bfg()
    {
        z[0] = 56;
        fog(z[]) = [56, 6, 8];
        assert(z[1] == 6);
        assert(z[0] == 56);
        return z[2];
    }
}

struct Vug
{
    Zadok p;
    int [] other;
}

int quop()
{
    int [] heap = new int[5];
    heap[] = 738;
    Zadok pong;
    pong.z = 3;
    int [] w = pong.z;
    assert(w[0]==3);
    Zadok phong;
    phong.z = 61;
    pong = phong;
    assert(w[0]==61);
    Vug b = Vug(Zadok(17, "abcd"));
    b = Vug(Zadok(17, "abcd"), heap);
    b.other[2] = 78;
    assert(heap[2]==78);
    char [] y = b.p.s;
    assert(y[2]=='c');
    phong.s = ['z','x','f', 'g'];
    w = b.p.z;
    assert(y[2]=='c');
    assert(w[0]==17);
    b.p = phong;
    assert(y[2]=='f');

    Zadok wok = Zadok(6, "xyzw");
    b.p = wok;
    assert(y[2]=='z');
    b.p = phong;
    assert(w[0] == 61);
    Vug q;
    q.p = pong;
    return pong.bfg();
}

static assert(quop()==8);
static assert(quop()==8); // check for clobbering

/**************************************************
   Bug 5676 tuple assign of struct that has void opAssign
**************************************************/

struct S5676
{
    int x;
    void opAssign(S5676 rhs) { x = rhs.x;}
}


struct Tup5676(E...)
{
    E g;
    void foo(E values) { g = values;   }
}

bool ice5676()
{
    Tup5676!(S5676) q;
    q.foo( S5676(3) );
    assert( q.g[0].x == 3);
    return true;
}

static assert(ice5676());

/**************************************************
   Bug 5682 Wrong CTFE with operator overloading
**************************************************/

struct A {
    int n;
    auto opBinary(string op : "*")(A rhs) {
        return A(n * rhs.n);
    }
}

A foo(A[] lhs, A[] rhs) {
    A current;
    for (size_t k = 0; k < rhs.length; ++k) {
        current = lhs[k] * rhs[k];
    }
    return current;
}

auto test() {
    return foo([A(1), A(2)], [A(3), A(4)]);
}

static assert(test().n == 8);

/**************************************************
   Attempt to modify a read-only string literal
**************************************************/
struct Xarg
{
   char [] s;
}
int zfs()
{
    auto q = Xarg(cast(char[])"abc");
    assert(q.s[1]=='b');
    q.s[1] = 'p';
    return 76;
}

static assert(!is(typeof(compiles!(zfs()))));

/**************************************************
   .dup must protect string literals
**************************************************/

string mutateTheImmutable(immutable string _s)
{
   char[] s = _s.dup;
   foreach(ref c; s)
       c = 'x';
   return s.idup;
}

string doharm(immutable string _name)
{
   return mutateTheImmutable(_name[2..$].idup);
}

enum victimLiteral = "CL_INVALID_CONTEXT";

enum thug = doharm(victimLiteral);
static assert(victimLiteral == "CL_INVALID_CONTEXT");


/**************************************************
        Use $ in a slice of a dotvar slice
**************************************************/

int sliceDollar()
{
    Xarg z;
    z.s = new char[20];
    z.s[] = 'b';
    z.s = z.s[2..$-2];
    z.s[$-2] = 'c';
    return z.s[$-2];
}
static assert(sliceDollar()=='c');

/**************************************************
   Variation of 5972 which caused segfault
**************************************************/

int bug5972crash()
{
  char [] z = "abc".dup;
  char[] [] a = [null, null];
  a[0]  = z[0..2];
  a[0][1] = 'q';
  return 56;
}
static assert(bug5972crash()==56);

/**************************************************
   String slice assignment through ref parameter
**************************************************/

void popft(A)(ref A a)
{
    a = a[1 .. $];
}

int sdfgasf()
{
    auto scp = "abc".dup;
    popft(scp);
    return 1;
}
static assert(sdfgasf() == 1);

/**************************************************
   Bug 6015
**************************************************/

struct Foo6015 {
    string field;
}

bool func6015(string input){
    Foo6015 foo;
    foo.field = input[0..$];
    assert(foo.field == "test");
    foo.field = "test2";
    assert(foo.field != "test");
    assert(foo.field == "test2");
    return true;
}

static assert(func6015("test"));

/**************************************************
   Bug 6001
**************************************************/

void bug6001e(ref int[] s) {
    int[] r = s;
    s ~= 0;
}
bool bug6001f() {
    int[] s;
    bug6001e(s);
    return true;
}
static assert(bug6001f());

// Assignment to AAs

void blah(int[char] as)
{
    auto k = [6: as];
    as = k[6];
}
int blaz()
{
    int[char] q;
    blah(q);
    return 67;
}
static assert(blaz()==67);

void bug6001g(ref int[] w)
{
    w = [88];
    bug6001e(w);
    w[0] = 23;
}

bool bug6001h() {
    int[] s;
    bug6001g(s);
    assert(s.length == 2);
    assert(s[1]== 0);
    assert(s[0]==23);
    return true;
}
static assert(bug6001h());

/**************************************************
   Bug 4910
**************************************************/

int bug4910(int a)
{
    return a;
}

static int var4910;
static assert(!is(typeof(Compiles!(bug4910(var4910)))));

static assert(bug4910(123));

/**************************************************
    Bug 5845 - Regression(2.041)
**************************************************/

void test5845(ulong cols) {}

uint solve(bool niv, ref ulong cols) {
    if (niv)
        solve(false, cols);
    else
        test5845(cols);
    return 65;
}

ulong nqueen(int n) {
    ulong cols    = 0;
    return solve(true, cols);
}

static assert(nqueen(2) == 65);

/**************************************************
    Bug 5258
**************************************************/

struct Foo5258 { int x; }
void bar5258(int n, ref Foo5258 fong) {
    if (n)
        bar5258(n - 1, fong);
    else
        fong.x++;
}
int bug5258() {
    bar5258(1, Foo5258());
    return 45;
}
static assert(bug5258()==45);


struct Foo5258b  { int[2] r; }
void baqopY(int n, ref int[2] fongo) {
    if (n)
        baqopY(n - 1, fongo);
    else
        fongo[0]++;
}
int bug5258b() {
    Foo5258b qq;
    baqopY(1, qq.r);
    return 618;
}
static assert(bug5258b()==618);

// Notice that this case involving reassigning the dynamic array
struct Foo5258c { int[] r; }
void baqop(int n, ref int[] fongo) {
    if (n)
        baqop(n - 1, fongo);
    else
    {
        fongo = new int[20];
        fongo[0]++;
    }
}
size_t bug5258c() {
    Foo5258c qq;
    qq.r = new int[30];
    baqop(1, qq.r);
    return qq.r.length;
}
static assert(bug5258c() == 20);

/**************************************************
    Bug 6049
**************************************************/

struct Bug6049 {
    int m;
    this(int x)  {  m = x; }
    invariant() { }
}

const Bug6049[] foo6049 = [Bug6049(6),  Bug6049(17)];

static assert(foo6049[0].m == 6);

/**************************************************
    Bug 6052
**************************************************/

struct Bug6052 {
    int a;
}

bool bug6052() {
    Bug6052[2] arr;
    for (int i = 0; i < 2; ++ i) {
        Bug6052 el = {i};
        Bug6052 ek = el;
        arr[i] = el;
        el.a = i + 2;
        assert(ek.a == i);      // ok
        assert(arr[i].a == i);  // fail
    }
    assert(arr[1].a == 1);  // ok
    assert(arr[0].a == 0);  // fail
    return true;
}

static assert(bug6052());

bool bug6052b() {
    int[][1] arr;
    int[1] z = [7];
    arr[0] = z;
    assert(arr[0][0] == 7);
    arr[0] = z;
    z[0] = 3;
    assert(arr[0][0] == 3);
    return true;
}

static assert(bug6052b());

struct Bug6052c {
    int x;
    this(int a) { x = a; }
}

int bug6052c()
{
    Bug6052c[] pieces = [];
    for (int c = 0; c < 2; ++ c)
        pieces ~= Bug6052c(c);
    assert(pieces[1].x == 1);
    assert(pieces[0].x == 0);
    return 1;
}
static assert(bug6052c()==1);
static assert(bug6052c()==1);


static assert({
    Bug6052c[] pieces = [];
    pieces.length = 2;
    int c = 0;
    pieces[0] = Bug6052c(c);
    ++c;
    pieces[1] = Bug6052c(c);
    assert(pieces[0].x == 0);
    return true;
}());

static assert({
    int[1][] pieces = [];
    pieces.length = 2;
    for (int c = 0; c < 2; ++ c)
        pieces[c][0] = c;
    assert(pieces[1][0] == 1);
    assert(pieces[0][0] == 0);
    return true;
}());


static assert({
    Bug6052c[] pieces = [];
    for (int c = 0; c < 2; ++ c)
        pieces ~= Bug6052c(c);
    assert(pieces[1].x == 1);
    assert(pieces[0].x == 0);
    return true;
}());


static assert({
    int[1] z = 7;
    int[1][] pieces = [z,z];
    pieces[1][0]=3;
    assert(pieces[0][0] == 7);
    pieces = pieces ~ [z,z];
    pieces[3][0] = 16;
    assert(pieces[2][0] == 7);
    pieces = [z,z] ~ pieces;
    pieces[5][0] = 16;
    assert(pieces[4][0] == 7);
    return true;
}());

/**************************************************
    Bug 6749
**************************************************/

struct CtState {
    string code;
}

CtState bug6749()
{
    CtState[] pieces;
    CtState r = CtState("correct");
    pieces ~= r;
    r = CtState("clobbered");
    return pieces[0];
}
static assert(bug6749().code == "correct");

/**************************************************
    Index + slice assign to function returns
**************************************************/

int[] funcRetArr(int[] a)
{
    return a;
}

int testFuncRetAssign()
{
    int [] x = new int[20];
    funcRetArr(x)[2] = 4;
    assert(x[2]==4);
    funcRetArr(x)[] = 27;
    assert(x[15]==27);
    return 5;
}
static assert(testFuncRetAssign() == 5);

int keyAssign()
{
        int[int] pieces;
        pieces[3] = 1;
        pieces.keys[0]= 4;
        pieces.values[0]=27;
        assert(pieces[3]== 1);
    return 5;
}
static assert(keyAssign()==5);


/**************************************************
    Bug 6054 -- AA literals
**************************************************/

enum x6054 = {
    auto p = {
        int[string] pieces;
        pieces[['a'].idup] = 1;
        return pieces;
    }();
    return p;
}();

/**************************************************
    Bug 6077
**************************************************/

enum bug6077 = {
  string s;
  string t;
  return s ~ t;
}();

/**************************************************
    Bug 6078 -- Pass null array by ref
**************************************************/

struct Foo6078 {
  int[] bar;
}

static assert( {
  Foo6078 f;
  int i;
  foreach (ref e; f.bar) {
    i += e;
  }
  return i;
}() == 0);

int bug6078(ref int[] z)
{
    int [] q = z;
    return 2;
}

static assert( {
  Foo6078 f;
  return bug6078(f.bar);
}() == 2);


/**************************************************
    Bug 6079 -- Array bounds checking
**************************************************/

static assert(!is(typeof(compiles!({
    int[] x = [1,2,3,4];
    x[4] = 1;
    return true;
}()
))));

/**************************************************
    Bug 6100
**************************************************/

struct S6100
{
    int a;
}

S6100 init6100(int x)
{
    S6100 s = S6100(x);
    return s;
}

static const S6100[2] s6100a = [ init6100(1), init6100(2) ];
static assert(s6100a[0].a == 1);

/**************************************************
    Bug 4825 -- failed with -inline
**************************************************/

int a4825() {
    int r;
    return r;
}

int b4825() {
    return a4825();
}

void c4825() {
    void d() {
        auto e = b4825();
    }
    static const int f = b4825();
}

/**************************************************
    Bug 5708 -- failed with -inline
**************************************************/
string b5708(string s) { return s; }
string a5708(string s) { return b5708(s); }

void bug5708() {
    void m() { a5708("lit"); }
    static assert(a5708("foo") == "foo");
    static assert(a5708("bar") == "bar");
}

/**************************************************
    Bug 6120 -- failed with -inline
**************************************************/

struct Bug6120(T) {
    this(int x) { }
}
static assert({
    auto s = Bug6120!int(0);
    return true;
}());

/**************************************************
    Bug 6123 -- failed with -inline
**************************************************/

struct Bug6123(T) {
    void f() {}
    // can also trigger if the struct is normal but f is template
}
static assert({
    auto piece = Bug6123!int(); 
    piece.f();
    return true;
}());

/**************************************************
    Bug 6053 -- ICE involving pointers
**************************************************/

static assert({
    int *a = null;
    assert(a is null);
    assert(a == null);
    return true;
}());

static assert({
    int b;
    int* a= &b;
    assert(a !is null);
    *a = 7;
    assert(b==7);
    assert(*a == 7);
    return true;
}());

int dontbreak6053()
{
    auto q = &dontbreak6053;
    void caz() {}
    auto tr = &caz;
    return 5;
}
static assert(dontbreak6053());

static assert({
    int a; *(&a) = 15;
    assert(a==15);
    assert(*(&a)==15);
    return true;
}());

static assert({
    int a=5, b=6, c=2;
    assert( *(c ? &a : &b) == 5);
    assert( *(!c ? &a : &b) == 6);
    return true;
}());

static assert({
    int a, b, c; (c ? a : b) = 1;
    return true;
}());

static assert({
    int a, b, c=1;
    int *p=&a; (c ? *p : b) = 51;
    assert(a==51);
    return true;
}());

/**************************************************
  Pointer arithmetic, dereference, and comparison
**************************************************/

// dereference null pointer
static assert(!is(typeof(compiles!({
    int a, b, c=1; int *p; (c ? *p : b) = 51; return 6;
}()
))));
static assert(!is(typeof(compiles!({
    int *a = null; assert(*a!=6); return 72;
}()
))));

// cannot <, > compare pointers to different arrays
static assert(!is(typeof(compiles!({
    int a[5]; int b[5]; bool c = (&a[0] > &b[0]);
    return 72;
}()
))));

// can ==, is,!is,!= compare pointers for different arrays
static assert({
    int a[5]; int b[5];
    assert(!(&a[0] == &b[0]));
    assert(&a[0] != &b[0]);
    assert(!(&a[0] is &b[0]));
    assert(&a[0] !is &b[0]);
    return 72;
}());

static assert({
    int a[5];
    a[0] = 25;
    a[1] = 5;
    int *b = &a[1];
    assert(*b == 5);
    *b = 34;
    int c = *b;
    *b += 6;
    assert(b == &a[1]);
    assert(b != &a[0]);
    assert(&a[0] < &a[1]);
    assert(&a[0] <= &a[1]);
    assert(!(&a[0] >= &a[1]));
    assert(&a[4] > &a[0]);
    assert(c==34);
    assert(*b ==40);
    assert(a[1] == 40);
    return true;
}());

static assert({
    int [12] x;
    int *p = &x[10];
    int *q = &x[4];
    return p-q;
}() == 6);

static assert({
    int [12] x;
    int *p = &x[10];
    int *q = &x[4];
    q = p;
    assert(p == q);
    q = &x[4];
    assert(p != q);
    q = q + 6;
    assert(q is p);
    return 6;
}() == 6);

static assert({
    int [12] x;
    int [] y = x[2..8];
    int *p = &y[4];
    int *q = &x[6];
    assert(p == q);
    p = &y[5];
    assert(p > q);
    p = p + 5; // OK, as long as we don't dereference
    assert(p > q);
    return 6;
}() == 6);

static assert({
    char [12] x;
    const(char) *p = "abcdef";
    const (char) *q = p;
    q = q + 2;
    assert(*q == 'c');
    assert(q > p);
    assert(q - p == 2);
    assert(p - q == -2);
    q = &x[7];
    p = &x[1];
    assert(q>p);
    return 6;
}() == 6);

/**************************************************
  6517 ptr++, ptr--
**************************************************/

int bug6517() {
    int[] arr = [1, 2, 3];
    auto startp = arr.ptr;
    auto endp = arr.ptr + arr.length;

    for(; startp < endp; startp++) {}
    startp = arr.ptr;
    assert(startp++ == arr.ptr);
    assert(startp != arr.ptr);
    assert(startp-- != arr.ptr);
    assert(startp == arr.ptr);

    return 84;
}

static assert(bug6517() == 84);


/**************************************************
  Out-of-bounds pointer assignment and deference
**************************************************/

int ptrDeref(int ofs, bool wantDeref)
{
    int a[5];
    int *b = &a[0];
    b = b + ofs; // OK
    if (wantDeref)
        return *b; // out of bounds
    return 72;
}

static assert(!is(typeof(compiles!(ptrDeref(-1, true)))));
static assert( is(typeof(compiles!(ptrDeref(4, true)))));
static assert( is(typeof(compiles!(ptrDeref(5, false)))));
static assert(!is(typeof(compiles!(ptrDeref(5, true)))));
static assert(!is(typeof(compiles!(ptrDeref(6, false)))));
static assert(!is(typeof(compiles!(ptrDeref(6, true)))));

/**************************************************
  Pointer +=
**************************************************/
static assert({
    int [12] x;
    int zzz;
    assert(&zzz);
    int *p = &x[10];
    int *q = &x[4];
    q = p;
    assert(p == q);
    q = &x[4];
    assert(p != q);    
    q += 4;
    assert(q == &x[8]);
    q = q - 2;
    q = q + 4;    
    assert(q is p);    
    return 6;
}() == 6);

/**************************************************
  Reduced version of bug 5615
**************************************************/

const(char)[] passthrough(const(char)[] x) {
    return x;
}

sizediff_t checkPass(Char1)(const(Char1)[] s)
{
    const(Char1)[] balance = s[1..$];
    return passthrough(balance).ptr - s.ptr;
}
static assert(checkPass("foobar")==1);

/**************************************************
  Pointers must not escape from CTFE
**************************************************/

struct Toq {
    const(char) * m;
}

Toq ptrRet(bool b) {
    string x = "abc";
    return Toq(b ? x[0..1].ptr: null);
}

static assert(is(typeof(compiles!(
{
    enum Toq boz = ptrRet(false); // OK - ptr is null
    Toq z = ptrRet(true); // OK -- ptr doesn't escape
    return 4;
}()
))));

static assert(!is(typeof(compiles!(
{
    enum Toq boz = ptrRet(true); // fail - ptr escapes
    return 4;
}()
))));

/**************************************************
    Pointers to struct members
**************************************************/

struct Qoz
{
    int w;
    int[3] yof;
}

static assert(
{
    int [3] gaz;
    gaz[2] = 3156;
    Toq z = ptrRet(true);
    auto p = z.m;
    assert(*z.m == 'a');
    assert(*p == 'a');
    auto q = &z.m;
    assert(*q == p);
    assert(**q == 'a');
    Qoz g = Qoz(2,[5,6,7]);
    auto r = &g.w;
    assert(*r == 2);
    r = &g.yof[1];
    assert(*r == 6);
    g.yof[0]=15;
    ++r;
    assert(*r == 7);
    r-=2;
    assert(*r == 15);
    r = &gaz[0];
    r+=2;
    assert(*r == 3156);
    return *p;
}() == 'a'
);

struct AList
{
    AList * next;
    int value;
    static AList * newList()
    {
        AList[] z = new AList[1];
        return &z[0];
    }
    static AList * make(int i, int j)
    {
        auto r = newList();
        r.next = (new AList[1]).ptr;
        r.value = 1;
        AList * z= r.next;
        (*z).value = 2;
        r.next.value = j;
        assert(r.value == 1);
        assert(r.next.value == 2);
        r.next.next = &(new AList[1])[0];
        assert(r.next.next != null);
        assert(r.next.next);
        r.next.next.value = 3;
        assert(r.next.next.value == 3);
        r.next.next = newList();
        r.next.next.value = 9;
        return r;
    }
    static int checkList()
    {
        auto r = make(1,2);
        assert(r.value == 1);
        assert(r.next.value == 2);
        assert(r.next.next.value == 9);
        return 2;
    }
}

static assert(AList.checkList()==2);

/**************************************************
    4065 [CTFE] AA "in" operator doesn't work
**************************************************/

bool bug4065(string s) {
    enum int[string] aa = ["aa":14, "bb":2];
    int *p = s in aa;
    if (s == "aa")
        assert(*p == 14);
    else if (s=="bb")
        assert(*p == 2);
    else assert(!p);
    int[string] zz;
    assert(!("xx" in zz));
    bool c = !p;
    return cast(bool)(s in aa);
}

static assert(!bug4065("xx"));
static assert(bug4065("aa"));
static assert(bug4065("bb"));

/**************************************************
    Pointers in ? :
**************************************************/

static assert(
{
    int[2] x;
    int *p = &x[1];
    return p ? true: false;
}());

/**************************************************
    Pointer slicing
**************************************************/

int ptrSlice()
{
    auto arr = new int[5];
    int * x = &arr[0];
    int [] y = x[0..5];
    x[1..3] = 6;
    ++x;
    x[1..3] = 14;
    assert(arr[1]==6);
    assert(arr[2]==14);
    x[-1..4]= 5;
    int [] z = arr[1..2];
    z.length = 4;
    z[$-1] = 17;
    assert(arr.length ==5);
    return 2;
}

static assert(ptrSlice()==2);

/**************************************************
    6344 - create empty slice from null pointer
**************************************************/

static assert({
    char* c = null;
    auto m = c[0..0];
    return true;
}());

/**************************************************
    4448 - labelled break + continue
**************************************************/

int bug4448()
{
    int n=2;
    L1:{ switch(n)
    {
       case 5:
        return 7;
       default:
       n = 5;
       break L1;
    }
    int w = 7;
    }
    return 3;
}

static assert(bug4448()==3);

int bug4448b()
{
    int n=2;
    L1:for (n=2; n<5; ++n)
    {
        for (int m=1; m<6; ++m)
        {
            if (n<3)
            {
                assert(m==1);
                continue L1;
            }
        }
        break;
    }
    return 3;
}

static assert(bug4448b()==3);

/**************************************************
    6281 - [CTFE] A null pointer '!is null' returns 'true'
**************************************************/

static assert(!{
    auto p = null;
    return p !is null;
}());
static assert(!{
    auto p = null;
    return p != null;
}());

/**************************************************
    6331 - evaluate SliceExp on if condition
**************************************************/

bool bug6331(string s)
{
    if (s[0..1])
        return true;
    return false;
}
static assert(bug6331("str"));

/**************************************************
    6283 - assign to AA with slice as index
**************************************************/

static assert({
    immutable p = "pp";
    int[string] pieces = [p: 0];
    pieces["qq"] = 1;
    return true;
}());

static assert({
    immutable renames = [0: "pp"];
    int[string] pieces;
    pieces[true ? renames[0] : "qq"] = 1;
    pieces["anything"] = 1;
    return true;
}());

static assert( {
    immutable qq = "qq";
    string q = qq;
    int[string] pieces = ["a":1];
    pieces[q] = 0;
    string w = "ab";
    int z = pieces[w[0..1]];
    assert(z == 1);
    return true;
}() );

/**************************************************
    6282 - dereference 'in' of an AA
**************************************************/

static assert({
    int [] w = new int[4];
    w[2] = 6;
    auto c = [5: w];
    auto kk  = (*(5 in c))[2];
    (*(5 in c))[2] = 8;
    (*(5 in c))[1..$-2] = 4;
    auto a = [4:"1"];
    auto n = *(4 in a);
    return n;
}() == "1");

/**************************************************
    6337 - member function call on struct literal
**************************************************/

struct Bug6337
{
    int k;
    void six() {
        k = 6;
    }
    int ctfe()
    {
        six();
        return k;
    }
}
static assert( Bug6337().ctfe() == 6);

/**************************************************
    6603 call manifest function pointer
**************************************************/

int f6603(int a) { return a+5; }
enum bug6603 = &f6603;
static assert(bug6603(6)==11);

/**************************************************
    6375
**************************************************/

struct D6375 {
    int[] arr;
}
A6375 a6375(int[] array) {
    return A6375(array);
}
struct A6375 {
    D6375* _data;
    this(int[] arr) {
        _data = new D6375;
        _data.arr = arr;
    }
    int[] data() {
        return _data.arr;
    }
}
static assert({
    int[] a = [ 1, 2 ];
    auto app2 = a6375(a);
    auto data = app2.data();
    return true;
}());

/**************************************************
    6280 Converting pointers to bool
**************************************************/

static assert({
    if ((0 in [0:0])) {}
    if ((0 in [0:0]) && (0 in [0:0])) {}
    return true;
}());

/**************************************************
    6276 ~=
**************************************************/

struct Bug6276{
    int[] i;
}
static assert({
    Bug6276 foo;
    foo.i ~= 1;
    foo.i ~= 2;
    return true;
}());

/**************************************************
    6374   ptr[n] = x, x = ptr[n]
**************************************************/

static assert({
    int[] arr = [1];
    arr.ptr[0] = 2;
    auto k = arr.ptr[0];
    assert(k==2);
    return arr[0];
}() == 2);

/**************************************************
    6306  recursion and local variables
**************************************************/

void recurse6306() {
    bug6306(false);
}

bool bug6306(bool b) {
    int x = 0;
    if (b)
        recurse6306();
    assert(x == 0);
    x = 1;
    return true;
}

static assert( bug6306(true) );

/**************************************************
    6386  ICE on unsafe pointer cast
**************************************************/

static assert(!is(typeof(compiles!({
    int x = 123;
    int* p = &x;
    float z;
    float* q = cast(float*)p;
    return true;
}()
))));

static assert({
    int [] x = [123, 456];
    int* p = &x[0];
    auto m = cast(const(int) *)p;
    auto q = p;
    return *q;
}());

/**************************************************
    6420  ICE on dereference of invalid pointer
**************************************************/

static assert({
    // Should compile, but pointer can't be dereferenced
    int x = 123;
    int* p = cast(int *)x;
    auto q = cast(char*)x;
    auto r = cast(char*)323;
    // Valid const-changing cast
    const float *m = cast(immutable float *)[1.2f,2.4f,3f];
    return true;
}()
);

static assert(!is(typeof(compiles!({
    int x = 123;
    int* p = cast(int *)x;
    int a = *p;
    return true;
}()
))));

static assert(!is(typeof(compiles!({
    int* p = cast(int *)123;
    int a = *p;
    return true;
}()
))));

static assert(!is(typeof(compiles!({
    auto k = cast(int*)45;
    *k = 1;
    return true;
}()
))));

static assert(!is(typeof(compiles!({
    *cast(float*)"a" = 4.0;
    return true;
}()
))));

static assert(!is(typeof(compiles!({
    float f = 2.8;
    long *p = &f;
    return true;
}()
))));

static assert(!is(typeof(compiles!({
    long *p = cast(long *)[1.2f,2.4f,3f];
    return true;
}()
))));


/**************************************************
    6250  deref pointers to array
**************************************************/

int []* simple6250(int []* x) { return x; }

void swap6250(int[]* lhs, int[]* rhs)
{
    int[] kk = *lhs;
    assert(simple6250(lhs) == lhs);
    lhs = simple6250(lhs);
    assert(kk[0] == 18);
    assert((*lhs)[0] == 18);
    assert((*rhs)[0] == 19);
    *lhs = *rhs;
    assert((*lhs)[0] == 19);
    *rhs = kk;
    assert(*rhs == kk);
    assert(kk[0] == 18);
    assert((*rhs)[0] == 18);
}

int ctfeSort6250()
{
     int[][2] x;
     int[3] a = [17, 18, 19];
     x[0] = a[1..2];
     x[1] = a[2..$];
     assert(x[0][0] == 18);
     assert(x[0][1] == 19);
     swap6250(&x[0], &x[1]);
     assert(x[0][0] == 19);
     assert(x[1][0] == 18);
     a[1] = 57;
     assert(x[0][0] == 19);
     return x[1][0];
}

static assert(ctfeSort6250()==57);

/**************************************************
    6672 circular references in array
**************************************************/

void bug6672(ref string lhs, ref string rhs)
{
    auto tmp = lhs;
    lhs = rhs;
    rhs = tmp;
}

static assert( {
    auto kw = ["a"];
    bug6672(kw[0], kw[0]);
    return true;
}());

void slice6672(ref string[2] agg, ref string lhs) { agg[0..$] = lhs; }

static assert( {
    string[2] kw = ["a", "b"];
    slice6672(kw, kw[0]);
    assert(kw[0] == "a");
    assert(kw[1] == "a");
    return true;
}());

// an unrelated rejects-valid bug
static assert( {
    string[2] kw = ["a", "b"];
    kw[0..2] = "x";
    return true;
}());

void bug6672b(ref string lhs, ref string rhs)
{
    auto tmp = lhs;
    assert(tmp == "a");
    lhs = rhs;
    assert(tmp == "a");
    rhs = tmp;
}

static assert( {
    auto kw=["a", "b"];
    bug6672b(kw[0], kw[1]);
    assert(kw[0]=="b");
    assert(kw[1]=="a");
    return true;
}());

/**************************************************
    6399 (*p).length = n
**************************************************/

struct A6399{
    int[] arr;
    int subLen()
    {
        arr = [1,2,3,4,5];
        arr.length -= 1;
        return cast(int)arr.length;
    }
}

static assert({
    A6399 a;
    return a.subLen();
}() == 4);

/**************************************************
    6418 member named 'length'
**************************************************/

struct Bug6418 {
    size_t length() { return 189; }
}
static assert(Bug6418.init.length == 189);

/**************************************************
    4021 rehash
**************************************************/

bool bug4021() {
    int[int] aa = [1: 1];
    aa.rehash;
    return true;
}
static assert(bug4021());

/**************************************************
    3512 foreach(dchar; string)
    6558 foreach(int, dchar; string)
**************************************************/

bool test3512()
{
    string s = "öhai";
    int q = 0;
    foreach (wchar c; s) {
        if (q==2) assert(c=='a');
        ++q;
    }
    assert(q==4);
    foreach (dchar c; s) { ++q; if (c=='h') break; } // _aApplycd1
    assert(q == 6);
    foreach (int i, wchar c; s) {
        assert(i >= 0 && i < s.length);
	}   // _aApplycw2
    foreach (int i, dchar c; s) {
        assert(i >= 0 && i < s.length);
	} // _aApplycd2

    wstring w = "xüm";
    foreach (char c; w) {++q; } // _aApplywc1
    assert(q == 10);
    foreach (dchar c; w) { ++q; } // _aApplywd1
    assert(q == 13);
    foreach (int i, char c; w) {
        assert(i >= 0 && i < w.length);
	} // _aApplywc2
    foreach (int i, dchar c; w) {
        assert(i >= 0 && i < w.length);
	} // _aApplywd2

    dstring d = "yäq";
    q = 0;
    foreach (char c; d) { ++q; } // _aApplydc1
    assert(q == 4);
    q = 0;
    foreach (wchar c; d) { ++q; } // _aApplydw1
    assert(q == 3);
    foreach (int i, char c; d) {
        assert(i >= 0 && i < d.length);
    } // _aApplydc2
    foreach (int i, wchar c; d) {
        assert(i >= 0 && i < d.length);
    } // _aApplydw2

    dchar[] dr = "squop"d.dup;
    foreach(int n, char c; dr) { if (n==2) break; assert(c!='o'); }
    foreach_reverse (char c; dr) {} // _aApplyRdc1
    foreach_reverse (wchar c; dr) {} // _aApplyRdw1
    foreach_reverse (int n, char c; dr) { if (n==4) break; assert(c!='o');} // _aApplyRdc2
    foreach_reverse (int i, wchar c; dr) {
        assert(i >= 0 && i < dr.length);
    } // _aApplyRdw2
    q = 0;
    wstring w2 = ['x', 'ü', 'm']; // foreach over array literals
    foreach_reverse (int n, char c; w2)
    {
        ++q;
        if (c == 'm') assert(n == 2 && q==1);
        if (c == 'x') assert(n == 0 && q==4);
    }
    return true;
}
static assert(test3512());

/**************************************************
    6510 ICE only with -inline
**************************************************/

struct Stack6510 {
    struct Proxy {
        void shrink() {}
    }
    Proxy stack;
    void pop() {
        stack.shrink();
    }
}

int bug6510() {
    static int used() {
        Stack6510 junk;
        junk.pop();
        return 3;
    }
    return used();
}

void test6510() {
    static assert(bug6510()==3);
}

/**************************************************
    6511   arr[] shouldn't make a copy
**************************************************/

T bug6511(T)() {
    T[1] a = [1];
    a[] += a[];
    return a[0];
}
static assert(bug6511!ulong() == 2);
static assert(bug6511!long() == 2);

/**************************************************
    6512   new T[][]
**************************************************/

bool bug6512(int m) {
    auto x = new int[2][][](m, 5);
    assert(x.length == m);
    assert(x[0].length == 5);
    assert(x[0][0].length == 2);
    foreach( i; 0.. m)
        foreach( j; 0..5)
            foreach(k; 0..2)
                x[i][j][k] = k + j*10 + i*100;
    foreach( i; 0.. m)
        foreach( j; 0..5)
            foreach(k; 0..2)
                assert( x[i][j][k] == k + j*10 + i*100);
    return true;
}
static assert(bug6512(3));

/**************************************************
    6516   ICE(constfold.c)
**************************************************/

dstring bug6516()
{
    return cast(dstring) new dchar[](0);
}

static assert(bug6516() == ""d);

/**************************************************
    6727   ICE(interpret.c)
**************************************************/

const(char) * ice6727(const(char) *z) { return z;}
static assert(
    {
        auto q = ice6727("a".dup.ptr);
        return true;
    }());

/**************************************************
    6721   Cannot get pointer to start of char[]
**************************************************/
static assert({
        char[] c1="".dup;
        auto p = c1.ptr;
        string c2="";
        auto p2 = c2.ptr;
        return 6;
    }() == 6);

/**************************************************
    6693   Assign to null AA
**************************************************/

struct S6693
{
    int[int] m;
}

static assert({
    int[int][int] aaa;
    aaa[3][1] = 4;
    int[int][3] aab;
    aab[2][1] = 4;
    S6693 s;
    s.m[2] = 4;
    return 6693;
 }() == 6693);

/**************************************************
    6739   Nested AA assignment
**************************************************/

static assert({
    int[int][int][int] aaa;
    aaa[3][1][6] = 14;
    return aaa[3][1][6];
}() == 14);

static assert({
    int[int][int] aaa;
    aaa[3][1] = 4;
    aaa[3][3] = 3;
    aaa[1][5] = 9;
    auto kk = aaa[1][5];
    return kk;
}() == 9);

/**************************************************
    6751   ref AA assignment
**************************************************/

void bug6751(ref int[int] aa){
    aa[1] = 2;
}

static assert({
    int[int] aa;
    bug6751(aa);
    assert(aa[1] == 2);
    return true;
}());

void bug6751b(ref int[int][int] aa){
    aa[1][17] = 2;
}

struct S6751
{
    int[int][int] aa;
    int[int] bb;
}

static assert({
    S6751 s;
    bug6751b(s.aa);
    assert(s.aa[1][17] == 2);
    return true;
}());

static assert({
    S6751 s;
    s.aa[7][56]=57;
    bug6751b(s.aa);
    assert(s.aa[1][17] == 2);
    assert(s.aa[7][56] == 57);
    bug6751c(s.aa);
    assert(s.aa.keys.length==1);
    assert(s.aa.values.length==1);
    return true;
}());

static assert({
    S6751 s;
    s.bb[19] = 97;
    bug6751(s.bb);
    assert(s.bb[1] == 2);
    assert(s.bb[19] == 97);
    return true;
}());

void bug6751c(ref int[int][int] aa){
    aa = [38: [56 : 77]];
}

/**************************************************
    6765   null AA.length
**************************************************/

static assert({
    int[int] w;
    return w.length;
}()==0);

/**************************************************
    6769   AA.keys, AA.values with -inline
**************************************************/

static assert({
    double[char[3]] w = ["abc" : 2.3];
    double[] z = w.values;
    return w.keys.length;
}() == 1);

/**************************************************
    4022   AA.get
**************************************************/

static assert({
    int[int] aa = [58: 13];
    int r = aa.get(58, 1000);
    assert(r == 13);
    r = aa.get(59, 1000);
    return r;
}() == 1000);

/**************************************************
    6775 AA.opApply
**************************************************/

static assert({
    int[int] aa = [58: 17, 45:6];
    int valsum = 0;
    int keysum = 0;
    foreach(m; aa) { //aaApply
        valsum += m;
    }
    assert(valsum == 17+6);
    valsum = 0;
    foreach(n, m; aa) { //aaApply2
        valsum += m;
        keysum += n;
    }
    assert(valsum == 17+6);
    assert(keysum == 58+45);
    // Check empty AA
    valsum = 0;
    int[int] bb;
    foreach(m; bb) {
        ++valsum;
    }
    assert(valsum == 0);
    return true;
}());

/**************************************************
    AA.remove
**************************************************/

static assert({
    int[int] aa = [58: 17, 45:6];
    aa.remove(45);
    assert(aa.length == 1);
    aa.remove(7);
    assert(aa.length == 1);
    aa.remove(58);
    assert(aa.length == 0);
    return true;
}());

/**************************************************
    try, finally
**************************************************/

static assert({
    int n = 0;
    try {
        n = 1;
    }
    catch (Exception e)
    {}
    assert(n == 1);
    try {
        n = 2;
    }
    catch (Exception e)
    {}
    finally {
        assert(n == 2);
        n = 3;
    }
    assert(n == 3);
    return true;
}());

/**************************************************
    6800 bad pointer casts
**************************************************/

bool badpointer(int k)
{
    int m = 6;
    int *w =  &m;
    assert(*w == 6);
    int [3] a = [17,2,21];
    int *w2 = &a[2];
    assert(*w2 == 21);

    // cast int* to uint* is OK
    uint* u1 = cast(uint*)w;
    assert(*u1 == 6);
    uint* u2 = cast(uint*)w2;
    assert(*u2 == 21);
    uint* u3 = cast(uint*)&m;
    assert(*u3 == 6);
    // cast int* to void* is OK
    void *v1 = cast(void*)w;
    void *v3 = &m;
    void *v4 = &a[0];
    // cast from void * back to int* is OK
    int *t3 = cast(int *)v3;
    assert(*t3 == 6);
    int *t4 = cast(int *)v4;
    assert(*t4 == 17);
    // cast from void* to uint* is OK
    uint *t1 = cast(uint *)v1;
    assert(*t1 == 6);
    // and check that they're real pointers
    m = 18;
    assert(*t1 == 18);
    assert(*u3 == 18);

    int **p = &w;

    if (k == 1) // bad reinterpret
        double *d1 = cast(double *)w;
    if (k == 3) // bad reinterpret
        char *d3 = cast(char *)w2;
    if (k == 4) {
        void *q1 = cast(void *)p;    // OK-void is int*
        void **q = cast(void **)p;   // OK-void is int
    }
    if (k == 5)
        void ***q = cast(void ***)p;  // bad: too many *
    if (k == 6) // bad reinterpret through void *
        double *d1 = cast(double*)v1;
    if (k == 7)
        double *d7 = cast(double*)v4;
    if (k==8)
        ++v4; // can't do pointer arithmetic on void *
    return true;
}
static assert(badpointer(4));
static assert(!is(typeof(compiles!(badpointer(1)))));
static assert(is(typeof(compiles!(badpointer(2)))));
static assert(!is(typeof(compiles!(badpointer(3)))));
static assert(is(typeof(compiles!(badpointer(4)))));
static assert(!is(typeof(compiles!(badpointer(5)))));
static assert(!is(typeof(compiles!(badpointer(6)))));
static assert(!is(typeof(compiles!(badpointer(7)))));
static assert(!is(typeof(compiles!(badpointer(8)))));

/**************************************************
    6792 ICE with pointer cast of indexed array
**************************************************/

struct S6792 {
    int i;
}

static assert({
    {
        void* p;
        p = [S6792(1)].ptr;
        S6792 s = *(cast(S6792*)p);
        assert(s.i == 1);
    }
    {
        void*[] ary;
        ary ~= [S6792(2)].ptr;
        S6792 s = *(cast(S6792*)ary[0]);
        assert(s.i == 2);
    }
    {
        void*[7] ary;
        ary[6]= [S6792(2)].ptr;
        S6792 s = *(cast(S6792*)ary[6]);
        assert(s.i == 2);
    }
    {
        void* p;
        p = [S6792(1)].ptr;
        void*[7] ary;
        ary[5]= p;
        S6792 s = *(cast(S6792*)ary[5]);
        assert(s.i == 1);
    }
    {
        S6792*[string] aa;
        aa["key"] = [S6792(3)].ptr;
        const(S6792) s = *(cast(const(S6792) *)aa["key"]);
        assert(s.i == 3);
    }
    {
        S6792[string] blah;
        blah["abc"] = S6792(6);
        S6792*[string] aa;
        aa["kuy"] = &blah["abc"];
        const(S6792) s = *(cast(const(S6792) *)aa["kuy"]);
        assert(s.i == 6);

        void*[7] ary;
        ary[5]= &blah["abc"];
        S6792 t = *(cast(S6792*)ary[5]);
        assert(t.i == 6);

        int Q= 6;
        ary[3]= &Q;
        int gg = *(cast(int*)(ary[3]));
    }
    return true;
}());

/**************************************************
    6851 passing pointer by argument
**************************************************/

void set6851(int* pn)
{
    *pn = 20;
}
void bug6851()
{
    int n = 0;
    auto pn = &n;
    *pn = 10;
    assert(n == 10);
    set6851(&n);
}
static assert({ bug6851(); return true; }());

/**************************************************
    6817 if converted to &&, only with -inline
**************************************************/
static assert({
    void toggle() {
        bool b;
        if (b)
            b = false;
    }
    toggle();
    return true;
}());

/**************************************************
    cast to void
**************************************************/

static assert({
    cast(void)(71);
    return true;
} ());

/**************************************************
    6816 nested function can't access this
**************************************************/

struct S6816 {
    size_t foo() {
        return (){ return value+1; }();
    }
    size_t value;
}

enum s6816 = S6816().foo();

/**************************************************
    classes and interfaces
**************************************************/

interface SomeInterface
{
  int daz();
  float bar(char);
  int baz();
}

interface SomeOtherInterface
{
    int xxx();
}

class TheBase : SomeInterface, SomeOtherInterface
{
    int q = 88;
    int rad = 61;
    int a = 14;
    int somebaseclassfunc() { return 28;}
    int daz() { return 0; }
    int baz() { return 0; }
    int xxx() { return 762; }
    int foo() { return q; }
    float bar(char c) { return 3.6; }
}

class SomeClass : TheBase, SomeInterface
{
    int gab = 9;
    int fab;
    int a = 17;
    int b = 23;
    int foo() { return gab + a; }
    float bar(char c) { return 2.6; }
    int something() { return 0; }
    int daz() { return 0; }
    int baz() { return 0; }
}

class Unrelated : TheBase {
    this(int x) { a = x; }
}

auto classtest1(int n)
{
    SomeClass c = new SomeClass;
    assert(c.a == 17);
    assert(c.q == 88);
    TheBase d = c;
    assert(d.a == 14);
    assert(d.q == 88);
    if (n==7)
    {   // bad cast -- should fail
        Unrelated u = cast(Unrelated)d;
    }
    SomeClass e = cast(SomeClass)d;
    d.q = 35;
    assert(c.q == 35);
    assert(c.foo() == 9 + 17);
    ++c.a;
    assert(c.foo() == 9 + 18);
    assert(d.foo() == 9 + 18);
    d = new TheBase;
    SomeInterface fc = c;
    SomeOtherInterface ot = c;
    assert(fc.bar('x') == 2.6);
    assert(ot.xxx() == 762);
    fc = d;
    ot = d;
    assert(fc.bar('x') == 3.6);
    assert(ot.xxx() == 762);

    Unrelated u2 = new Unrelated(7);
    assert(u2.a == 7);
    return 6;
}
static assert(classtest1(1));
static assert(is(typeof(compiles!(classtest1(2)))));
static assert(!is(typeof(compiles!(classtest1(7)))));

// can't return classes literals outside CTFE
SomeClass classtest2(int n)
{
    return n==5 ? (new SomeClass) : null;
}
static assert(is(typeof( (){ enum xx = classtest2(2);}() )));
static assert(!is(typeof( (){ enum xx = classtest2(5);}() )));

class RecursiveClass
{
   int x;
   this(int n) { x = n; }
   RecursiveClass b;
   void doit() { b = new RecursiveClass(7); b.x = 2;}
}

int classtest3()
{
    RecursiveClass x = new RecursiveClass(17);
    x.doit();
    RecursiveClass y = x.b;
    assert(y.x == 2);
    assert(x.x == 17);
    return 1;
}

static assert(classtest3());

/**************************************************
    6885 wrong code with new array
**************************************************/

struct S6885 {
    int p;
}

int bug6885()
{
    auto array = new double[1][2];
    array[1][0] = 6;
    array[0][0] = 1;
    assert(array[1][0]==6);

    auto barray = new S6885[2];
    barray[1].p = 5;
    barray[0].p = 2;
    assert(barray[1].p == 5);
    return 1;
}

static assert(bug6885());

/**************************************************
    6886 ICE with new array of dynamic arrays
**************************************************/

int bug6886()
{
    auto carray = new int[][2];
    carray[1] = [6];
    carray[0] = [4];
    assert(carray[1][0]==6);
    return 1;
}

static assert(bug6886());

/****************************************************
 * Exception chaining tests from xtest46.d
 ****************************************************/
class A75
{
    pure static void raise(string s)
    {
        throw new Exception(s);
    }
}

int test75()
{   int x = 0;
    try
    {
	A75.raise("a");
    } catch (Exception e)
    {
	x = 1;
    }
    assert(x == 1);
    return 1;
}
static assert(test75());

/****************************************************
 * Exception chaining tests from test4.d
 ****************************************************/

int test4_test54()
{
	int status=0;

	try
	{
		try
		{
			status++;
			assert(status==1);
			throw new Exception("first");
		}
		finally
		{
			status++;
			assert(status==2);
			status++;
			throw new Exception("second");
		}
	}
	catch(Exception e)
	{
        assert(e.msg == "first");
        assert(e.next.msg == "second");
	}
	return true;
}

static assert(test4_test54());

void foo55()
{
    try
    {
	Exception x = new Exception("second");
	throw x;
    }
    catch (Exception e)
    {
	assert(e.msg == "second");
    }
}

int test4_test55()
{
	int status=0;
	try{
		try{
			status++;
			assert(status==1);
			Exception x = new Exception("first");
			throw x;
		}finally{
			status++;
			assert(status==2);
			status++;
			foo55();
		}
	}catch(Exception e){
		assert(e.msg == "first");
		assert(status==3);
	}
    return 1;
}

static assert(test4_test55());

/****************************************************
 * Exception chaining tests from eh.d
 ****************************************************/

void bug1513outer()
{
    int result1513;

    void bug1513a()
    {
         throw new Exception("d");
    }

    void bug1513b()
    {
        try
        {
            try
            {
                bug1513a();
            }
            finally
            {
                result1513 |=4;
               throw new Exception("f");
            }
        }
        catch(Exception e)
        {
            assert(e.msg == "d");
            assert(e.next.msg == "f");
            assert(!e.next.next);
        }
    }

    void bug1513c()
    {
        try
        {
            try
            {
                throw new Exception("a");
            }
            finally
            {
                result1513 |= 1;
                throw new Exception("b");
            }
        }
        finally
        {
            bug1513b();
            result1513 |= 2;
            throw new Exception("c");
        }
    }

    void bug1513()
    {
        result1513 = 0;
        try
        {
            bug1513c();
        }
        catch(Exception e)
        {
            assert(result1513 == 7);
            assert(e.msg == "a");
            assert(e.next.msg == "b");
            assert(e.next.next.msg == "c");
        }
    }

    bug1513();
}

void collideone()
{
    try
    {
        throw new Exception("x");
    }
    finally
    {
        throw new Exception("y");
    }
}

void doublecollide()
{
    try
    {
        try
        {
            try
            {
                throw new Exception("p");
            }
            finally
            {
                throw new Exception("q");
            }
        }
        finally
        {
            collideone();
        }
    }
    catch(Exception e)
    {
            assert(e.msg == "p");
            assert(e.next.msg == "q");
            assert(e.next.next.msg == "x");
            assert(e.next.next.next.msg == "y");
            assert(!e.next.next.next.next);
    }
}

void collidetwo()
{
       try
        {
            try
            {
                throw new Exception("p2");
            }
            finally
            {
                throw new Exception("q2");
            }
        }
        finally
        {
            collideone();
        }
}

void collideMixed()
{
    int works = 6;
    try
    {
        try
        {
            try
            {
                throw new Exception("e");
            }
            finally
            {
                throw new Error("t");
            }
        }
        catch(Exception f)
        {    // Doesn't catch, because Error is chained to it.
            works += 2;
        }
    }
    catch(Error z)
    {
        works += 4;
        assert(z.msg=="t"); // Error comes first
        assert(z.next is null);
        assert(z.bypassedException.msg == "e");
    }
    assert(works == 10);
}

class AnotherException : Exception
{
    this(string s)
    {
        super(s);
    }
}

void multicollide()
{
    try
    {
       try
        {
            try
            {
                try
                {
                    throw new Exception("m2");
                }
                finally
                {
                    throw new AnotherException("n2");
                }
            }
            catch(AnotherException s)
            {   // Not caught -- we needed to catch the root cause "m2", not
                // just the collateral "n2" (which would leave m2 uncaught).
                assert(0);
            }
        }
        finally
        {
            collidetwo();
        }
    }
    catch(Exception f)
    {
        assert(f.msg == "m2");
        assert(f.next.msg == "n2");
        Throwable e = f.next.next;
        assert(e.msg == "p2");
        assert(e.next.msg == "q2");
        assert(e.next.next.msg == "x");
        assert(e.next.next.next.msg == "y");
        assert(!e.next.next.next.next);
    }
}

int testsFromEH()
{
    bug1513outer();
    doublecollide();
    collideMixed();
    multicollide();
    return 1;
}
static assert(testsFromEH());

/**************************************************
    With + synchronized statements + bug 6901
**************************************************/

struct With1
{
    int a;
    int b;
}

class Foo6
{
}

class Foo32
{
   struct Bar
   {
	int x;
   }
}

class Base56
{
    private string myfoo;
    private string mybar;

    // Get/set properties that will be overridden.
    void foo(string s) { myfoo = s; }
    string foo() { return myfoo; }

    // Get/set properties that will not be overridden.
    void bar(string s) { mybar = s; }
    string bar() { return mybar; }
}

class Derived56: Base56
{
    alias Base56.foo foo; // Bring in Base56's foo getter.
    override void foo(string s) { super.foo = s; } // Override foo setter.
}


int testwith()
{
    With1 x = With1(7);
    with(x)
    {
        a = 2;
    }
    assert(x.a == 2);

    // from test11.d
    Foo6 foo6 = new Foo6();

    with (foo6)
    {
        int xx;
        xx = 4;
    }
    with (new Foo32)
    {
        Bar z;
        z.x = 5;
    }
    Derived56 d = new Derived56;
    with (d)
    {
        foo = "hi";
        d.foo = "hi";
        bar = "hi";
        assert(foo == "hi");
        assert(d.foo == "hi");
        assert(bar == "hi");
    }
    int w = 7;
    synchronized {
        ++w;
    }
    assert(w == 8);
    return 1;
}

static assert(testwith());

/**************************************************
    6416 static struct declaration
**************************************************/

static assert({
    static struct S { int y = 7; }
    S a;
    a.y += 6;
    assert(a.y == 13);
    return true;
}());

/**************************************************
    6522 opAssign + foreach
**************************************************/

struct Foo6522 {
    bool b = false;
    void opAssign(int x) {
        this.b = true;
    }
}

bool foo6522() {
    Foo6522[1] array;
    foreach (ref item; array)
        item = 1;
    return true;
}

static assert(foo6522());

/**************************************************
    6919
**************************************************/

void bug6919(int* val)
{
    *val = 1;
}
void test6919()
{
    int n;
    bug6919(&n);
    assert(n == 1);
}
static assert({ test6919(); return true; }());

void bug6919b(string* val)
{
    *val = "1";
}

void test6919b()
{
    string val;
    bug6919b(&val);
    assert(val == "1");
}
static assert({ test6919b(); return true; }());
