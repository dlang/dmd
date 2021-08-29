/* test bitfields
 * DISABLED: win32 win64 linux64 freebsd64 osx64
 * RUN_OUTPUT:
---
T0 = 1 1 | 1 1
T1 = 2 2 | 2 2
T2 = 4 4 | 4 4
T3 = 8 4 | 8 8
T4 = 12 4 | 16 8
T5 = 8 4 | 8 8
S1 = 4 4 | 8 8
S2 = 4 4 | 4 4
S3 = 4 4 | 4 4
S4 = 4 4 | 4 4
S5 = 4 4 | 4 4
S6 = 2 2 | 2 2
S7 = 4 4 | 8 8
S8 = 2 2 | 2 2
S8A = 2 2 | 2 2
S8B = 2 2 | 2 2
S8C = 4 4 | 4 4
S9  = 4 2 | 4 2
S10 = 0 1 | 0 1
S11 = 0 1 | 0 1
S12 = 4 4 | 4 4
S13 = 8 4 | 8 4
S14 = 8 4 | 8 4
S15 = 4 4 | 4 4
S16 = 4 1 | 4 1
S17 = 4 4 | 4 4
S18 = 5 1 | 9 1
A0  = 12 4 | 16 8
S9 = x30200
S14 = x300000201
S15 = xe01
S18 = 4 should be 4
A0 = xf00000001
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

struct T0  { char x:1; };                            // 1 1
struct T1  { short x:1; };                           // 2 2
struct T2  { int x:1; };                             // 4 4
struct T3  { char a,b,c,d; long long x:1; };         // 8 8
struct T4  { char a,b,c,d,e,f,g,h; long long x:1; }; // 16 8
struct T5  { char a,b,c,d,e,f,g; long long x:1; };   // 8 8
struct S1  { long long int f:1; };                   // 8 8
struct S2  { int x:1; int y:1; };                    // 4 4
struct S3  { short c; int x:1; unsigned y:1; };      // 4 4
struct S4  { int x:1; short y:1; };                  // 4 4
struct S5  { short x:1; int y:1; };                  // 4 4
struct S6  { short x:1; short y:1; };                // 2 2
struct S7  { short x:1; int y:1; long long z:1; };   // 8 8
struct S8  { char a; char b:1; short c:2; };         // 2 2
struct S8A { char b:1; short c:2; };                 // 2 2
struct S8B { char a; short b:1; char c:2; };         // 2 2
struct S8C { char a; int b:1; };                     // 4 4
struct S9  { char a; char b:2; short c:9; };         // 4 2 x30201
struct S10 { };                                      // 0 1
struct S11 { int :0; };                              // 0 1
struct S12 { int :0; int x; };                       // 4 4
struct S13 { unsigned x:12; unsigned x1:1; unsigned x2:1; unsigned x3:1; unsigned x4:1; int w; }; // 8 4
struct S14 { char a; char b:4; int c:30; };          // 8 4
struct S15 { char a; char b:2; int c:9; };           // 4 4 xe01
struct S16 { int :32; };                             // 4 1
struct S17 { int a:32; };                            // 4 4
struct S18 { char a; long long :0; char b; };        // 5 1 (32 bit) 9 1 (64 bit)
struct A0  { int a; long long b:34, c:4; };          // 12 4 (32 bit) 16 8 (64 bit)

int main()
{
    printf("T0 = %d %d | 1 1\n", (int)sizeof(struct T0), (int)_Alignof(struct T0));
    printf("T1 = %d %d | 2 2\n", (int)sizeof(struct T1), (int)_Alignof(struct T1));
    printf("T2 = %d %d | 4 4\n", (int)sizeof(struct T2), (int)_Alignof(struct T2));
    printf("T3 = %d %d | 8 8\n", (int)sizeof(struct T3), (int)_Alignof(struct T3));
    printf("T4 = %d %d | 16 8\n", (int)sizeof(struct T4), (int)_Alignof(struct T4));
    printf("T5 = %d %d | 8 8\n", (int)sizeof(struct T5), (int)_Alignof(struct T5));
    printf("S1 = %d %d | 8 8\n", (int)sizeof(struct S1), (int)_Alignof(struct S1));
    printf("S2 = %d %d | 4 4\n", (int)sizeof(struct S2), (int)_Alignof(struct S2));
    printf("S3 = %d %d | 4 4\n", (int)sizeof(struct S3), (int)_Alignof(struct S3));
    printf("S4 = %d %d | 4 4\n", (int)sizeof(struct S4), (int)_Alignof(struct S4));
    printf("S5 = %d %d | 4 4\n", (int)sizeof(struct S5), (int)_Alignof(struct S5));
    printf("S6 = %d %d | 2 2\n", (int)sizeof(struct S6), (int)_Alignof(struct S6));
    printf("S7 = %d %d | 8 8\n", (int)sizeof(struct S7), (int)_Alignof(struct S7));
    printf("S8 = %d %d | 2 2\n", (int)sizeof(struct S8), (int)_Alignof(struct S8));
    printf("S8A = %d %d | 2 2\n", (int)sizeof(struct S8A), (int)_Alignof(struct S8A));
    printf("S8B = %d %d | 2 2\n", (int)sizeof(struct S8B), (int)_Alignof(struct S8B));
    printf("S8C = %d %d | 4 4\n", (int)sizeof(struct S8C), (int)_Alignof(struct S8C));
    printf("S9  = %d %d | 4 2\n", (int)sizeof(struct S9),  (int)_Alignof(struct S9));
    printf("S10 = %d %d | 0 1\n", (int)sizeof(struct S10), (int)_Alignof(struct S10));
    printf("S11 = %d %d | 0 1\n", (int)sizeof(struct S11), (int)_Alignof(struct S11));
    printf("S12 = %d %d | 4 4\n", (int)sizeof(struct S12), (int)_Alignof(struct S12));
    printf("S13 = %d %d | 8 4\n", (int)sizeof(struct S13), (int)_Alignof(struct S13));
    printf("S14 = %d %d | 8 4\n", (int)sizeof(struct S14), (int)_Alignof(struct S14));
    printf("S15 = %d %d | 4 4\n", (int)sizeof(struct S15), (int)_Alignof(struct S15));
    printf("S16 = %d %d | 4 1\n", (int)sizeof(struct S16), (int)_Alignof(struct S16));
    printf("S17 = %d %d | 4 4\n", (int)sizeof(struct S17), (int)_Alignof(struct S17));
    printf("S18 = %d %d | 9 1\n", (int)sizeof(struct S18), (int)_Alignof(struct S18));
    printf("A0  = %d %d | 16 8\n", (int)sizeof(struct A0),  (int)_Alignof(struct A0));

    {
        struct S9 s;
        *(unsigned *)&s = 0;
        s.b = 2; s.c = 3;
        unsigned x = *(unsigned *)&s;
        printf("S9 = x%x\n", x);
    }
    {
        struct S14 s = { 1, 2, 3 };
        *(long long *)&s = 0;
        s.a = 1;
        s.b = 2;
        s.c = 3;
        unsigned long long v = *(unsigned long long *)&s;
        printf("S14 = x%llx\n", v);
    }
    {
        struct S15 s = { 1,2,3 };
        *(unsigned *)&s = 0;
        s.a = 1; s.b = 2; s.c = 3;
        unsigned x = *(unsigned *)&s;
        printf("S15 = x%x\n", x);
    }
    {
        struct S18 s;
        printf("S18 = %d should be %d\n", (int)(&s.b - &s.a), is64bit() ? 8 : 4);
    }
    {
        struct A0 s;
        *(long long *)&s = 0;
        s.a = 1; s.b = 15;
        long long x = *(long long *)&s;
        printf("A0 = x%llx\n", x);
    }

    return 0;
}


