/* test bitfields
 * DISABLED: win32 win64 linux32 freebsd32 osx32
 * RUN_OUTPUT:
---
T0 = 1 1 | 1 1
T1 = 2 2 | 2 2
T2 = 4 4 | 4 4
T3 = 8 8 | 8 8
T4 = 16 8 | 16 8
T5 = 8 8 | 8 8
S1 = 8 8 | 8 8
S2 = 4 4 | 4 4
S3 = 4 4 | 4 4
S4 = 4 4 | 4 4
S5 = 4 4 | 4 4
S6 = 2 2 | 2 2
S7 = 8 8 | 8 8
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
S18 = 9 1 | 9 1
A0  = 16 8 | 16 8
A1  = 12 4 | 12 4
A2  = 12 4 | 12 4
A3  = 16 4 | 16 4
A4  = 8 4 | 8 4
A5  = 2 1 | 2 1
A6  = 2 2 | 2 2
A7  = 16 8 | 16 8
A8  = 8 8 | 8 8
A9  = 16 8 | 16 8
A10 = 2 2 | 2 2
A11 = 12 4 | 12 4
S9 = x30200
S14 = x300000201
S15 = xe01
S18 = 8 should be 8
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

struct T0  { char x:1; };                            // 1 1
struct T1  { short x:1; };                           // 2 2
struct T2  { int x:1; };                             // 4 4
struct T3  { char a,b,c,d; long long x:1; };         // 8 4 (32 bit) 8 8 (64 bit)
struct T4  { char a,b,c,d,e,f,g,h; long long x:1; }; // 12 4 (32 bit) 16 8 (64 bit)
struct T5  { char a,b,c,d,e,f,g; long long x:1; };   // 8 4 (32 bit) 8 8 (64 bit)
struct S1  { long long int f:1; };                   // 4 4 (32 bit) 8 8 (64 bit)
struct S2  { int x:1; int y:1; };                    // 4 4
struct S3  { short c; int x:1; unsigned y:1; };      // 4 4
struct S4  { int x:1; short y:1; };                  // 4 4
struct S5  { short x:1; int y:1; };                  // 4 4
struct S6  { short x:1; short y:1; };                // 2 2
struct S7  { short x:1; int y:1; long long z:1; };   // 4 4 (32 bit) 8 8 (64 bit)
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
struct A1  { int a; unsigned b:11; int c; };         // 12 4
struct A2  { int a; unsigned b:11, c:5, d:16;        // 12 4
             int e; };
struct A3  { int a; unsigned b:11, c:5, :0, d:16;    // 16 4
             int e; };
struct A4  { int a:8; short b:7;                     // 8 4
             unsigned int c:29; };
struct A5  { char a:7, b:2; };                       // 2 1
struct A6  { char a:7; short b:2; };                 // 2 2
struct A7  { short a:8; long b:16; int c;            // 12 4 (32 bit) 16 8 (64 bit)
             char d:7; };
struct A8  { short a:8; long b:16; int :0;           // 8 4 (32 bit) 8 8 (64 bit)
             char c:7; };
struct A9  { unsigned short a:8; long b:16;          // 16 4 (32 bit) 16 8 (64 bit)
             unsigned long c:29; long long d:9;
             unsigned long e:2, f:31; };
struct A10 { unsigned short a:8; char b; };          // 2 2
struct A11 { char a; int b:5, c:11, :0, d:8;         // 12 4
             struct { int ee:8; } e; };

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
    printf("A0  = %d %d | 16 8\n", (int)sizeof(struct A0), (int)_Alignof(struct A0));
    printf("A1  = %d %d | 12 4\n", (int)sizeof(struct A1), (int)_Alignof(struct A1));
    printf("A2  = %d %d | 12 4\n", (int)sizeof(struct A2), (int)_Alignof(struct A2));
    printf("A3  = %d %d | 16 4\n", (int)sizeof(struct A3), (int)_Alignof(struct A3));
    printf("A4  = %d %d | 8 4\n", (int)sizeof(struct A4), (int)_Alignof(struct A4));
    printf("A5  = %d %d | 2 1\n", (int)sizeof(struct A5), (int)_Alignof(struct A5));
    printf("A6  = %d %d | 2 2\n", (int)sizeof(struct A6), (int)_Alignof(struct A6));
    printf("A7  = %d %d | 16 8\n", (int)sizeof(struct A7), (int)_Alignof(struct A7));
    printf("A8  = %d %d | 8 8\n", (int)sizeof(struct A8), (int)_Alignof(struct A8));
    printf("A9  = %d %d | 16 8\n", (int)sizeof(struct A9), (int)_Alignof(struct A9));
    printf("A10 = %d %d | 2 2\n", (int)sizeof(struct A10), (int)_Alignof(struct A10));
    printf("A11 = %d %d | 12 4\n", (int)sizeof(struct A11), (int)_Alignof(struct A11));

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
