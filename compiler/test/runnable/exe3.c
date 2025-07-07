/*_ exe3.c   Mon Nov 20 1989   Modified by: Walter Bright */
/* Copyright (C) 1986-1989 by Walter Bright     */
/* All Rights Reserved                          */
/* Test basic floating point operations         */

#include        <stdio.h>
#include        <stdlib.h>
#include        <assert.h>
#include        <math.h>
#include        <float.h>
//#include      <fltpnt.h>

int _8087 = 0;

/************************************************/

#if 0 // does not have fltpnt.h
static unsigned long nanarray[2] = {1,0x7FF80000 };
#define DNANQ   (*(double *)nanarray)

static unsigned long nansarray[2] = {1,0x7FF00000 };
#define DNANS   (*(double *)nansarray)

static unsigned long infinityarray[2] = {0,0x7FF00000 };
#define DINFINITY       (*(double *)infinityarray)

static unsigned long subnormalarray[2] = {1,0x00000000 };
#define DSUBNORMAL      (*(double *)subnormalarray)

static unsigned long fnanarray = 0x7FC00001;
#define FNANQ   (*(double *)fnanarray)

static unsigned long fnansarray = 0x7F800001;
#define FNANS   (*(double *)fnansarray)

static unsigned long finfinityarray = 0x7F800000;
#define FINFINITY       (*(double *)finfinityarray)

static unsigned long fsubnormalarray = 0x00000001;
#define FSUBNORMAL      (*(double *)fsubnormalarray)


void testclassify()
{
printf("%d, %lx, %lx\n",fpclassify(DNANQ),nanarray[0],nanarray[1]);
        assert(fpclassify(DNANQ) == FP_NANQ);
//      assert(fpclassify(DNANS) == FP_NANS);
        assert(fpclassify(DINFINITY) == FP_INFINITE);
        assert(fpclassify(0.0) == FP_ZERO);
        assert(fpclassify(0.1) == FP_NORMAL);
        assert(fpclassify(DSUBNORMAL) == FP_SUBNORMAL);

#if 0
        assert(fpclassify(FNANQ) == FP_NANQ);
        assert(fpclassify(FNANS) == FP_NANS);
        assert(fpclassify(FINFINITY) == FP_INFINITE);
        assert(fpclassify(0.0f) == FP_ZERO);
        assert(fpclassify(0.1f) == FP_NORMAL);
        assert(fpclassify(FSUBNORMAL) == FP_SUBNORMAL);
#endif
}
#endif

/************************************************/

const double abc1 = 2.0;

void testflt()
{       double a,b,c,*pa,*pb;
        float f;
        int i;
        long l;

        a = 3;
        b = 4;
        /*printf("a = %g, b = %g\n",a,b);*/
        assert(a + b == 7);
        assert(a - b == -1);
        assert(a * b == 12);
        assert(a / b == .75);
        i = a;
        assert(i == 3);
        a = i;
        assert(a == 3.);
        l = b;
        assert(l == 4);
        b = l;
        assert(b == 4.);
        assert(a < b);
        assert(a <= b);
        assert(b > a);
        assert(b >= a);
        assert(a != b);
        b = -b;
        assert(a > b);
        assert(a >= b);
        assert(b < a);
        assert(b <= a);
        a = -b;
        assert(a != b);
        a = 1024;                       /* look at second word  */
        b = 1025;
        assert(a < b);
        assert(a <= b);
        assert(b > a);
        assert(b >= a);
        assert(a != b);
        b = -b;
        assert(a > b);
        assert(a >= b);
        assert(b < a);
        assert(b <= a);
        a = -b;
        assert(a != b);

        assert(a > 1);
        assert(a > 100);
        assert(a > fabs(100));

        a = 4567;
        f = a;
        assert(f == 4567.);
        b = f;
        assert(b == a);

        a = -3.1415926;
        b = -57.3e-10;
        printf("a = %e, b = %e\n",a,b);

        a = 5;
        b = a++;
        assert(b == 5);
        assert(a == 6);
        pa = &a;
        pb = &b;
        *pb = (*pa)++;
        assert(b == 6);
        assert(a == 7);
        assert(a > *pb);
}

/************************************************/

void dblops()
{
        double a,b,c,d;

        a = 0; b = 5;
        assert(a * b == 0);
        assert(b * a == 0);
        assert(a + b == 5);
        assert(b + a == 5);
        assert(a - b == -5);
        assert(b - a == 5);
        assert(a / b == 0);
        assert((a ? b : a * 3) == 0);
        assert((b ? b + 2 : a) == 7);

        a = 1; b = 2;
        assert(a + b == 3);
        assert(a - b == -1);
        assert(a * b == 2);
        assert(a / b == .5);

        a = 1;
        c = a++; assert(c == 1);
        c = a--; assert(c == 2);
        c = ++a; assert(c == 2);
        c = --a; assert(c == 1);
        assert(a--);
        assert(!a++);
        assert((c = a--) != 0);
        assert((c = a++) == 0);
        assert((c = --a) == 0);
        assert((c = ++a) != 0);

        a = 0;
        c = -a;
        assert(c == 0);
        assert(c >= 0);
        assert(c <= 0);
        assert(c <= 1);
        assert(c < 1);
        assert(c >= -1);
        assert(c > -1);

        a = 1024;
        b = 1025;
        assert(a != b);
        assert(a < b);
        assert(a <= b);
        assert(b > a);
        assert(b >= a);
}

void fltops()
{
        float a,b,c,d;

        a = 0; b = 5;
        assert(a * b == 0);
        assert(b * a == 0);
        assert(a + b == 5);
        assert(b + a == 5);
        assert(a - b == -5);
        assert(b - a == 5);
        assert(a / b == 0);
        assert((a ? b : a * 3) == 0);
        assert((b ? b + 2 : a) == 7);

        a = 1; b = 2;
        assert(a + b == 3);
        assert(a - b == -1);
        assert(a * b == 2);
        assert(a / b == .5);

        a = 1;
        c = a++; assert(c == 1);
        c = a--; assert(c == 2);
        c = ++a; assert(c == 2);
        c = --a; assert(c == 1);
        assert(a--);
        assert(!a++);
        assert((c = a--) != 0);
        assert((c = a++) == 0);
        assert((c = --a) == 0);
        assert((c = ++a) != 0);

        a = 0;
        c = -a;
        assert(c == 0);
        assert(c >= 0);
        assert(c <= 0);
        assert(c <= 1);
        assert(c < 1);
        assert(c >= -1);
        assert(c > -1);

        a = 1024;
        b = 1025;
        assert(a != b);
        assert(a < b);
        assert(a <= b);
        assert(b > a);
        assert(b >= a);
}

float intfloat()
{       int i = 7;

        return (float) i;
}

float intfloat2()
{       static int i = 8;

        return i;
}

void conversions()
{
        void fcse(double,double,double);
        double d;
        float f;
        signed char sc;
        unsigned char uc;
        short i;
        unsigned short ui;
        long l;
        unsigned long ul;

#define X(x,val) x= val;d=x;assert(fabs(d- val)<.01);x=d;assert(x == val);

        X(f,64);
        X(uc,53);
        X(sc,-23);
        X(uc,230);
        X(i,30000);
        X(i,30000L);
        X(ui,50000);
        X(ui,50000L);
        X(l,100000);
#if !__OS2__
        X(ul,0xFFFFF000L);
#endif

#undef X

        f = 7.5;
        fcse(-f,f,-f);

        /* Test rounding (should truncate towards 0)    */
        d = 5.9;
        i = d;
        assert(i == 5);
        ui = d;
        assert(ui == 5);
        l = d;
        assert(l == 5);

        d = -5.9;
        i = d;
        assert(i == -5);
        ui = d;
        printf("ui == %d\n",ui);
        /*assert(ui == 0);*/            /* not implemented correctly yet */
        l = d;
        assert(l == -5);

        d = 32767;
        i = d;
        printf("i == %d\n",i);
        assert(i == 32767);
        d = -32768;
        i = d;
        printf("i == %d\n",i);
        assert(i == -32768);
        d = 65535;
        ui = d;
        printf("ui == %d\n",ui);
        assert(ui == 65535);

    {
        double xhi,xki;

        xhi=1.5;
        xki=(unsigned)xhi;
        assert(xki == 1);
        xki=(long)xhi;
        assert(xki == 1);
        xki=(int)xhi;
        assert(xki == 1);
    }
    assert(intfloat() == 7);
    assert(intfloat2() == 8);

    {
        long l;
        unsigned long ul;
        double d,ud;


        l = 0x7FFFFFFF;
        ul = l + 1;
        d = l;
        ud = ul;
        /*printf("d = %g, ud = %g, ud-d = %g\n",d,ud,ud - d);*/
        assert(d + 1 == ud);
        l = d;
        ul = ud;
        assert(l + 1 == ul);
    }
    {
        long l;
        unsigned long ul;
        float d,ud;


        l = 0x7FFFFFFF;
        ul = l + 1;
        d = l;
        ud = ul;
        /*printf("d = %g, ud = %g, ud-d = %g\n",d,ud,ud - d);*/
//      assert(d + 1 == ud);
//      l = d;
//      ul = ud;
//      assert(l == ul);
    }
    {
        unsigned long x = 0xFFFFFFFF;

        x = x * 0.838096515;
        assert(x == 0xD68D7E41);
    }
}

void fcse(f1,f2,f3)
double f1,f2,f3; // float should work, too, but doesn't
{

        assert(f1 == -7.5);
        assert(f2 == 7.5);
        assert(f3 == f1);
}

void initializations()
{       static  float f1 = 1, f2 = (double) 2, f3 = 3., f4 = (int) 4.2;
                float f5 = 5, f6 = (double) 6, f7 = 7., f8 = (int) 8.2;
        static struct S { int a; char b,c; float d; char e; int f; char g;}
                s = {1,2,3,4,5,6,7};

        assert(f1 == 1);
        assert(f2 == 2);
        assert(f3 == 3);
        assert(f4 == 4);
        assert(f5 == 5);
        assert(f6 == 6);
        assert(f7 == 7);
        assert(f8 == 8);

        assert(s.a == 1);
        assert(s.b == 2);
        assert(s.c == 3);
        assert(s.d == 4);
        assert(s.e == 5);
        assert(s.f == 6);
        assert(s.g == 7);
}

void floats()
{       float f,*pf;
        double d,*pd;
        float x = 5,y = 6,z = 7;

        x = z * y;
        z = z * 10;
        y = y * 10;
        assert(x == 42);
        assert(z == 70);
        assert(y == 60);

        f = 15.;
        pf = &f;
        assert(f == fabs(*pf));
        assert(*pf == fabs(f));
        assert(f + f == 30.);
        d = 8;
        *pf = d;
        d = *pf;
        assert(d == 8);
        ++f;
        assert(f == 9);
        --f;
        assert(f == 8);

        f = 0.0;
        pf = &f;
        *pf += exp(1.0);
        assert(f == *pf);

        d = 0.0;
        pd = &d;
        *pd += exp(1.0);
        assert(d == *pd);
}

#if 0
double fabs(x)
double x;
{       return (x < 0) ? -x : x; }
#endif

void comsubs()
{       double a,b[3];
        int i;

        b[2] = 6.0;
        i = 2;
        a = b[i] - b[i];
        assert(a == 0);
}

/***********************************************/

#if __cplusplus
int para1(char *,char *,char **);
#endif

void parameters()
{       static char a[] = "abcd";
        char *b = "efg";
        char *c[1];

        c[0] = "hij";
        para1(a,b,c);
}

int para1(a,b,c)
char a[],*b,*c[];
{
        assert(*a == 'a' && a[1] == 'b');
        assert(*b == 'e' && b[1] == 'f');
        assert(**c == 'h' && c[0][1] == 'i');
        return 0;
}

/***********************************************/

#if __cplusplus
int funcp(float *pf1,float *pf2,char *pc1);
int func2(double,double,int);
#endif
void func3(float,float,char);
void func4(double,double,int);

void parameters2()
{
        func2(1.0,2.0,0x1234);
        func3(1.0,2.0,(char)0x1234);
        func4(1.0,2.0,0x1234);
}

int func2(f1,f2,c1)
float f1,f2;
char c1;
{
    assert(c1 == 0x34);
    assert(f1 == 1.0);
    assert(f2 == 2.0);
    funcp(&f1,&f2,&c1);
    return 0;
}

void func3(float f1,float f2,char c1)
{
    assert(c1 == 0x34);
    assert(f1 == 1.0);
    assert(f2 == 2.0);
    funcp(&f1,&f2,&c1);
}

void func4(f1,f2,c1)
double f1,f2; int c1; //float f1,f2; char c1; this should work, bug in ImportC
{
//    assert(c1 == 0x34); // bug in ImportC
    assert(f1 == 1.0);
    assert(f2 == 2.0);
}


int funcp(float *pf1,float *pf2,char *pc1)
{
    assert(*pc1 == 0x34);
    assert(*pf1 == 1.0);
    assert(*pf2 == 2.0);
    return 0;
}

/***********************************************/

void scoping()
{{
        int a,b;

        a = 1;
        b = 2;
        assert(a == 1);
        assert(b == 2);
        {{      int c,d;

                c = 3;
                d = 4;
                assert(a == 1);
                assert(b == 2);
                assert(c == 3);
                assert(d == 4);
        }}
        {{      int e,f;

                e = 5;
                f = 6;
                assert(a == 1);
                assert(b == 2);
                assert(e == 5);
                assert(f == 6);
        }}
        assert(a == 1);
        assert(b == 2);
}}

/* Test handling of overflow of 8087 stack      */

int smooth(buf,c,x)
int buf[][3];
double c[];
int x;
{
        int tmp;

        tmp =
        c[2] * 1 + c[1] * 2 + c[2] * 3 +
        c[1] * 4 + c[0] * 5 + c[1] * 6 +
        c[2] * 7 + c[1] * 8 + c[2] * 9;

        return tmp;
}

void overflow()
{
        static double c[3] = {0.2,0.1,0.1};
        static int buf[3][3] = {1,2,3,
                                4,5,6,
                                7,8,9};
        int i;

        /*printf("i = %d, status = b%b\n",i,_status87());*/
#if !(M_UNIX || M_XENIX)
        i = smooth(buf,c,1);
        assert(i == 5);
#endif
        /*printf("i = %d, status = b%b\n",i,_status87());*/
}

void testsave87()
{
        double r,q,u;
        q = -16;
        r = 0;
        u=q/(r ? fabs(q) : -fabs(q));
        assert(u == 1);
}

/****************** COMPILE-ONLY TESTS *****************/

double ViewingTrans[4][2][3];

void ApplyViewingTrans(Location, World, Screen)
int Location;
int World[];
int Screen[];
{       double d;

 Screen[0] = 200;
 d = ((double) Screen[0]);
}

/************/

char *p(in)
float in;
{
    char  *errmess="";
    float xpos = 2.5,j,k;
    short trans = 0;

    if ( in+xpos > (trans ? j : k) )
        errmess = "x axis length negative or too long";
    return( errmess );
}

/******************
 * Don't link in library routine.
 */

double exp(arg)
double arg;
{
        atof("1.2345");         /* destroy all registers        */
        return 2.718;
}

/******************** COMPILE ONLY **********************/

double midexp()
{
    static double s=0;
    return s=s++;
}

/***************************************/

float ff() { return 6; }

double dd()
{
        return ff() + ff();
}

void testfltto87()
{
        assert(dd() == 12.);
}

/***************************************/

int ysizedec;
int ysize2;
int ysize;

double testfr();

void testfrd( void ) {
    ysize=(int)(testfr());
    ysizedec=ysize - 1;
    ysize2=ysize / 2;
    assert(ysize2 == 50);
}

double testfr() { return 100.23456; }

/***************************************/

#if __ZTC__ >= 0x220

double pascal fltretp(double x)
{
        if (x < 0)
                return x + 1;
        else
                return x;
}

float _fortran fltretf(float x)
{
        if (x < 0)
        {       x--;
                return x;
        }
        else
                return x;
}

void testfltret()
{
        assert(fltretp(-5) == -4);
        assert(fltretf(-5) == -6);
}

#else
#define testfltret()
#endif

/***************************************/

void testhex()
{
#if __ZTC__ >= 0x220
        double d;
        static long dx[2] = { 0x789abcdf,0x3ff23456 };

        d = 0x1.23456789ABCDEFp0;
        printf("d = %g, %08lx%08lx\n",d,((long*)&d)[1],((long*)&d)[0]);
        assert(d == *(double *)dx);

        d = 0x1.23456789ABCDEFp2;
        printf("d = %g, %08lx%08lx\n",d,((long*)&d)[1],((long*)&d)[0]);

        d = 0x1p-23;
        printf("d = %g, %08lx%08lx\n",d,((long*)&d)[1],((long*)&d)[0]);
        assert(d == FLT_EPSILON);

        assert(0x1.FFFFFEp127 == 0x.FFFFFFp128);
        assert(FLT_MAX == 0x1.FFFFFEp127);
        assert(FLT_MIN == 0x1p-126);
#endif
}

/***************************************/

void testdashf()
{
    double q;

    q=1;

    assert(q == 1);
    if (q==1) printf("OK:       q == 1 \n");

    if (q>=1) printf("OK:       q >= 1 \n");
    else      assert(0);
}

/***************************************/

void testfabsf()
{   float x,y;

    y = 10;
    x = 10;
    assert(fabsf(x) == y);
    x = -x;
    assert(fabsf(x) == y);
    x = fabs(x * 2);
    assert(fabsf(x) == 20);
}

/***************************************/

void testfabs()
{   double x,y;

    y = 10;
    x = 10;
    assert(fabs(x) == y);
    x = -x;
    assert(fabs(x) == y);
    x = fabs(x * 2);
    assert(fabs(x) == 20);
}

/***************************************/

void testfabsl()
{   long double x,y;

    y = 10;
    x = 10;
    assert(fabsl(x) == y);
    x = -x;
    assert(fabsl(x) == y);
    x = fabs(x * 2);
    assert(fabsl(x) == 20);
}

/***************************************/

void testassert0(double x)      { assert(x == 0); }

double afunc() {return 1;}
double bfunc() {return 2;}
double cfunc() {return 3;}
int ifunc() {return 1;};

void testf()
{
        double result;

        result = afunc()-(cfunc()-bfunc());
        //printf("afunc()-(cfunc()-bfunc())=%f (should be 0)\n",result);
        testassert0(result);
        result = afunc()-ifunc();
        testassert0(result);
        //printf("afunc()-ifunc()=%f (should be 0)\n",result);
}

/***************************************/

void testcln()
{
#if __ZTC__ >= 0x310
    static double x = 3;
    int pjv;

    pjv = -x != 0;
    assert(pjv == 1);
#endif
}

/***************************************/

#define ABS(a) ((a) <0 ? -(a) : (a))
void testabsm()
{
    double a=0;
    if (ABS(a) == 0.0)
        {}
    else
        assert(0);
}

/***************************************/

float txx()
{
    float x;
    return x/1000;      /* compile only */
}

/***************************************/

void func635(double d) {}

void test635(void)
{
  float x;

  for (x = 0; x<5.0; x+=1.0)    {
        func635( 2.0 <= (3.0 < x ? 3.0 : x) ? (3.0 < x ? 3.0 : x)
                                            : 2.0 );
        }
}

/***************************************/

double vnormi_(double *a, long n)
{
  double max, t;

  max = fabs(*a);
  while (--n)
    if ((t = fabs(*(++a))) > max)
      max = t;

  return max;
}

static double d[2];

void testdbl87()
{
  long i,m;
  double err;

  m = 2;

  d[0] = 0;
  d[1] = 0;

  printf("Start tests...\n\n");

  err = vnormi_(d,m);
  if (err != 0.0)
        assert(0);
  else
        printf("norm(x) is O.K. !\n");

  printf("d[0] = %lf, d[1] = %lf\n", d[0], d[1]);
}

/***************************************/

double xxx() { return 1; }

void testmn()
{
    int i = 1;

    if ((double)(int)xxx() != xxx())
        i--;
    assert(i == 1);
}

/***************************************/

void testfdivp()
{
#if !__INLINE_8087
    double x = 4195835.0;
    double y = 3145727.0;
    double z;

    z = x - (x / y) * y;
    assert(z < 1.0);
#endif
}

/***************************************/

void tidy()
{
#if 0 && __SC__ >= 0x750
 double x = INFINITY;

 if( (0.0 * x) == 0.0 ){
  assert(0);
 }

 if( (0 * x) == 0.0 ){
  assert(0);
 }

 if( !isnan(0.0 * x) ){
  assert(0);
 }

 if( !isnan(0 * x) ){
  assert(0);
 }
#endif
}

/***************************************/

void RealExpression(long double v1, long double v2, long double v3)
{
    assert(v1 == 0);
    assert(v2 == 1);
    assert(v3 == 37);
}

void NegExpconstFold(long double x)
{
        RealExpression(0,x,37);
}

void testld()
{
    long double x = 2.0;
    long double y = 4.0;

    x /= y;
    assert(x == 0.5);
    NegExpconstFold(1);
}

/***************************************/

void testdbl99()
{
        double d;

        d = 08.5;
        printf("d = %g\n", d);
        assert(d == 8.5);
        d = 09.;
        printf("d = %g\n", d);
        assert(d == 9);
        d = 09e0;
        printf("d = %g\n", d);
        assert(d == 9);
}

/***************************************/

int main()
{
        printf("File %s\n",__FILE__);

        printf("_8087 = %d\n",_8087);
        while (1)
        {       printf(_8087 ? "with 8087\n" : "without 8087\n");

                //testclassify();
//              testflt(); https://github.com/dlang/dmd/issues/21142
                dblops();
                fltops();
                conversions();
                initializations();
                floats();
                comsubs();
                parameters();
                parameters2();
                scoping();
                overflow();
                testsave87();
                testfltto87();
                testfrd();
                testfltret();
                testhex();
                testfabsf();
                testfabs();
                testfabsl();
                testf();
                testcln();
                testabsm();
                test635();
                testdbl87();
                testmn();
                tidy();
                if (_8087 == 0)
                    break;
                _8087 -= _8087;
        }
        testld();
        testdbl99();
        printf("SUCCESS\n");
        return EXIT_SUCCESS;
}
