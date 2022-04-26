/* test bitfields for Digital Mars C
 * Note that this test is for win32 only
 *
 * REQUIRED_ARGS:
 * DISABLED: win32mscoff win64 linux freebsd osx
 * RUN_OUTPUT:
---
                DM |   MS |  P32 |  P64
T0  =  1 1 ||  1 1 |  1 1 |  1 1 |  1 1
T1  =  2 2 ||  2 2 |  2 2 |  2 2 |  2 2
T2  =  4 4 ||  4 4 |  4 4 |  4 4 |  4 4
T3  = 16 8 || 16 8 | 16 8 |  8 4 |  8 8
T4  = 16 8 || 16 8 | 16 8 | 12 4 | 16 8
T5  = 16 8 || 16 8 | 16 8 |  8 4 |  8 8
S1  =  8 8 ||  8 8 |  8 8 |  4 4 |  8 8
S2  =  4 4 ||  4 4 |  4 4 |  4 4 |  4 4
S3  =  8 4 ||  8 4 |  8 4 |  4 4 |  4 4
S4  =  8 4 ||  8 4 |  8 4 |  4 4 |  4 4
S5  =  8 4 ||  8 4 |  8 4 |  4 4 |  4 4
S6  =  2 2 ||  2 2 |  2 2 |  2 2 |  2 2
S7  = 16 8 || 16 8 | 16 8 |  4 4 |  8 8
S8  =  4 2 ||  4 2 |  4 2 |  2 2 |  2 2
S8A =  4 2 ||  4 2 |  4 2 |  2 2 |  2 2
S8B =  6 2 ||  6 2 |  6 2 |  2 2 |  2 2
S8C =  8 4 ||  8 4 |  8 4 |  4 4 |  4 4
S9  =  4 2 ||  4 2 |  4 2 |  4 2 |  4 2
S10 =  0 0 ||  0 0 |  * * |  0 1 |  0 1
S11 =  0 0 ||  0 0 |  4 1 |  0 1 |  0 1
S12 =  4 4 ||  4 4 |  4 4 |  4 4 |  4 4
S13 =  8 4 ||  8 4 |  8 4 |  8 4 |  8 4
S14 =  8 4 ||  8 4 |  8 4 |  8 4 |  8 4
S15 =  8 4 ||  8 4 |  8 4 |  4 4 |  4 4
S16 =  0 0 ||  0 0 |  4 4 |  4 1 |  4 1
S17 =  4 4 ||  4 4 |  4 4 |  4 4 |  4 4
S18 =  2 1 ||  2 1 |  2 1 |  5 1 |  9 1
A0  = 16 8 || 16 8 | 16 8 | 12 4 | 16 8
A1  = 12 4 || 12 4 | 12 4 | 12 4 | 12 4
A2  = 12 4 || 12 4 | 12 4 | 12 4 | 12 4
A3  = 16 4 || 16 4 | 16 4 | 16 4 | 16 4
A4  = 12 4 || 12 4 | 12 4 |  8 4 |  8 4
A5  =  2 1 ||  2 1 |  2 1 |  2 1 |  2 1
A6  =  4 2 ||  4 2 |  4 2 |  2 2 |  2 2
A7  = 16 4 || 16 4 | 16 4 | 12 4 | 16 8
A8  = 12 4 || 12 4 | 12 4 |  8 4 |  8 8
A9  = 32 8 || 32 8 | 32 8 | 16 4 | 16 8
A10 =  4 2 ||  4 2 |  4 2 |  2 2 |  2 2
A11 = 16 4 || 16 4 | 16 4 | 12 4 | 12 4
S9 = x30200
S14 = x300000201
S15 = x201
S18 = 1 should be 4
A0 = x1
---
 */

int printf(const char *fmt, ...);
void exit(int);

void assert(int n, int b)
{
    if (!b)
    {
        printf("assert fail %d\n", n);
        exit(1);
    }
}

int is64bit() { return sizeof(long) == 8; }  // otherwise assume 32 bit

/*************************************************************/

struct T0  { char x:1; };                            //
struct T1  { short x:1; };                           //
struct T2  { int x:1; };                             //
struct T3  { char a,b,c,d; long long x:1; };         //
struct T4  { char a,b,c,d,e,f,g,h; long long x:1; }; //
struct T5  { char a,b,c,d,e,f,g; long long x:1; };   //
struct S1  { long long int f:1; };                   //
struct S2  { int x:1; int y:1; };                    //
struct S3  { short c; int x:1; unsigned y:1; };      //
struct S4  { int x:1; short y:1; };                  //
struct S5  { short x:1; int y:1; };                  //
struct S6  { short x:1; short y:1; };                //
struct S7  { short x:1; int y:1; long long z:1; };   //
struct S8  { char a; char b:1; short c:2; };         //
struct S8A { char b:1; short c:2; };                 //
struct S8B { char a; short b:1; char c:2; };         //
struct S8C { char a; int b:1; };                     //
struct S9  { char a; char b:2; short c:9; };         //
struct S10 { };                                      //
struct S11 { int :0; };                              //
struct S12 { int :0; int x; };                       //
struct S13 { unsigned x:12; unsigned x1:1; unsigned x2:1; unsigned x3:1; unsigned x4:1; int w; }; //
struct S14 { char a; char b:4; int c:30; };          //
struct S15 { char a; char b:2; int c:9; };           //
struct S16 { int :32; };                             //
struct S17 { int a:32; };                            //
struct S18 { char a; long long :0; char b; };        //
struct A0  { int a; long long b:34, c:4; };          //
struct A1  { int a; unsigned b:11; int c; };         //
struct A2  { int a; unsigned b:11, c:5, d:16;        //
             int e; };
struct A3  { int a; unsigned b:11, c:5, :0, d:16;    //
             int e; };
struct A4  { int a:8; short b:7;                     //
             unsigned int c:29; };
struct A5  { char a:7, b:2; };                       //
struct A6  { char a:7; short b:2; };                 //
struct A7  { short a:8; long b:16; int c;            //
             char d:7; };
struct A8  { short a:8; long b:16; int :0;           //
             char c:7; };
struct A9  { unsigned short a:8; long b:16;          //
             unsigned long c:29; long long d:9;
             unsigned long e:2, f:31; };
struct A10 { unsigned short a:8; char b; };          //
struct A11 { char a; int b:5, c:11, :0, d:8;         //
             struct { int ee:8; } e; };

int main()
{
    /* MS produces identical results for 32 and 64 bit compiles,
     * DM is 32 bit only
     */
    printf("                DM |   MS |  P32 |  P64\n");
    printf("T0  = %2d %d ||  1 1 |  1 1 |  1 1 |  1 1\n", (int)sizeof(struct T0), (int)_Alignof(struct T0));
    printf("T1  = %2d %d ||  2 2 |  2 2 |  2 2 |  2 2\n", (int)sizeof(struct T1), (int)_Alignof(struct T1));
    printf("T2  = %2d %d ||  4 4 |  4 4 |  4 4 |  4 4\n", (int)sizeof(struct T2), (int)_Alignof(struct T2));
    printf("T3  = %2d %d || 16 8 | 16 8 |  8 4 |  8 8\n", (int)sizeof(struct T3), (int)_Alignof(struct T3));
    printf("T4  = %2d %d || 16 8 | 16 8 | 12 4 | 16 8\n", (int)sizeof(struct T4), (int)_Alignof(struct T4));
    printf("T5  = %2d %d || 16 8 | 16 8 |  8 4 |  8 8\n", (int)sizeof(struct T5), (int)_Alignof(struct T5));
    printf("S1  = %2d %d ||  8 8 |  8 8 |  4 4 |  8 8\n", (int)sizeof(struct S1), (int)_Alignof(struct S1));
    printf("S2  = %2d %d ||  4 4 |  4 4 |  4 4 |  4 4\n", (int)sizeof(struct S2), (int)_Alignof(struct S2));
    printf("S3  = %2d %d ||  8 4 |  8 4 |  4 4 |  4 4\n", (int)sizeof(struct S3), (int)_Alignof(struct S3));
    printf("S4  = %2d %d ||  8 4 |  8 4 |  4 4 |  4 4\n", (int)sizeof(struct S4), (int)_Alignof(struct S4));
    printf("S5  = %2d %d ||  8 4 |  8 4 |  4 4 |  4 4\n", (int)sizeof(struct S5), (int)_Alignof(struct S5));
    printf("S6  = %2d %d ||  2 2 |  2 2 |  2 2 |  2 2\n", (int)sizeof(struct S6), (int)_Alignof(struct S6));
    printf("S7  = %2d %d || 16 8 | 16 8 |  4 4 |  8 8\n", (int)sizeof(struct S7), (int)_Alignof(struct S7));
    printf("S8  = %2d %d ||  4 2 |  4 2 |  2 2 |  2 2\n", (int)sizeof(struct S8), (int)_Alignof(struct S8));
    printf("S8A = %2d %d ||  4 2 |  4 2 |  2 2 |  2 2\n", (int)sizeof(struct S8A), (int)_Alignof(struct S8A));
    printf("S8B = %2d %d ||  6 2 |  6 2 |  2 2 |  2 2\n", (int)sizeof(struct S8B), (int)_Alignof(struct S8B));
    printf("S8C = %2d %d ||  8 4 |  8 4 |  4 4 |  4 4\n", (int)sizeof(struct S8C), (int)_Alignof(struct S8C));
    printf("S9  = %2d %d ||  4 2 |  4 2 |  4 2 |  4 2\n", (int)sizeof(struct S9),  (int)_Alignof(struct S9));
    printf("S10 = %2d %d ||  0 0 |  * * |  0 1 |  0 1\n", (int)sizeof(struct S10), (int)_Alignof(struct S10)); // MS doesn't compile
    printf("S11 = %2d %d ||  0 0 |  4 1 |  0 1 |  0 1\n", (int)sizeof(struct S11), (int)_Alignof(struct S11));
    printf("S12 = %2d %d ||  4 4 |  4 4 |  4 4 |  4 4\n", (int)sizeof(struct S12), (int)_Alignof(struct S12));
    printf("S13 = %2d %d ||  8 4 |  8 4 |  8 4 |  8 4\n", (int)sizeof(struct S13), (int)_Alignof(struct S13));
    printf("S14 = %2d %d ||  8 4 |  8 4 |  8 4 |  8 4\n", (int)sizeof(struct S14), (int)_Alignof(struct S14));
    printf("S15 = %2d %d ||  8 4 |  8 4 |  4 4 |  4 4\n", (int)sizeof(struct S15), (int)_Alignof(struct S15));
    printf("S16 = %2d %d ||  0 0 |  4 4 |  4 1 |  4 1\n", (int)sizeof(struct S16), (int)_Alignof(struct S16));
    printf("S17 = %2d %d ||  4 4 |  4 4 |  4 4 |  4 4\n", (int)sizeof(struct S17), (int)_Alignof(struct S17));
    printf("S18 = %2d %d ||  2 1 |  2 1 |  5 1 |  9 1\n", (int)sizeof(struct S18), (int)_Alignof(struct S18));
    printf("A0  = %2d %d || 16 8 | 16 8 | 12 4 | 16 8\n", (int)sizeof(struct A0),  (int)_Alignof(struct A0));
    printf("A1  = %2d %d || 12 4 | 12 4 | 12 4 | 12 4\n", (int)sizeof(struct A1),  (int)_Alignof(struct A1));
    printf("A2  = %2d %d || 12 4 | 12 4 | 12 4 | 12 4\n", (int)sizeof(struct A2),  (int)_Alignof(struct A2));
    printf("A3  = %2d %d || 16 4 | 16 4 | 16 4 | 16 4\n", (int)sizeof(struct A3),  (int)_Alignof(struct A3));
    printf("A4  = %2d %d || 12 4 | 12 4 |  8 4 |  8 4\n", (int)sizeof(struct A4),  (int)_Alignof(struct A4));
    printf("A5  = %2d %d ||  2 1 |  2 1 |  2 1 |  2 1\n", (int)sizeof(struct A5),  (int)_Alignof(struct A5));
    printf("A6  = %2d %d ||  4 2 |  4 2 |  2 2 |  2 2\n", (int)sizeof(struct A6),  (int)_Alignof(struct A6));
    printf("A7  = %2d %d || 16 4 | 16 4 | 12 4 | 16 8\n", (int)sizeof(struct A7),  (int)_Alignof(struct A7));
    printf("A8  = %2d %d || 12 4 | 12 4 |  8 4 |  8 8\n", (int)sizeof(struct A8),  (int)_Alignof(struct A8));
    printf("A9  = %2d %d || 32 8 | 32 8 | 16 4 | 16 8\n", (int)sizeof(struct A9),  (int)_Alignof(struct A9));
    printf("A10 = %2d %d ||  4 2 |  4 2 |  2 2 |  2 2\n", (int)sizeof(struct A10), (int)_Alignof(struct A10));
    printf("A11 = %2d %d || 16 4 | 16 4 | 12 4 | 12 4\n", (int)sizeof(struct A11), (int)_Alignof(struct A11));

    {
        struct S9 s;
        unsigned x;
        *(unsigned *)&s = 0;
        s.b = 2; s.c = 3;
        x = *(unsigned *)&s;
        printf("S9 = x%x\n", x);
    }
    {
        struct S14 s = { 1, 2, 3 };
        unsigned long long v;
        *(long long *)&s = 0;
        s.a = 1;
        s.b = 2;
        s.c = 3;
        v = *(unsigned long long *)&s;
        printf("S14 = x%llx\n", v);
    }
    {
        struct S15 s = { 1,2,3 };
        unsigned x;
        *(unsigned *)&s = 0;
        s.a = 1; s.b = 2; s.c = 3;
        x = *(unsigned *)&s;
        printf("S15 = x%x\n", x);
    }
    {
        struct S18 s;
        printf("S18 = %d should be %d\n", (int)(&s.b - &s.a), is64bit() ? 8 : 4);
    }
    {
        struct A0 s;
        long long x;
        *(long long *)&s = 0;
        s.a = 1; s.b = 15;
        x = *(long long *)&s;
        printf("A0 = x%llx\n", x);
    }

    return 0;
}
