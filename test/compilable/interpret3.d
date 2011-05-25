// PERMUTE_ARGS:

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

// Interpreter code coverage tests
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

template compiles(int T)
{
   bool compiles = true;
}

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

//static assert(bug5524(3) == 10);


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
             Bug 5671
*******************************************/

static assert( ['a', 'b'] ~ "c" == "abc" );

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
int bug5258c() {
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
