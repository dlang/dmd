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
