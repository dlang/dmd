/* https://issues.dlang.org/show_bug.cgi?id=15399
TEST_OUTPUT:
---
fail_compilation/test15399.d(48): Error: field `S1.ptr` cannot modify misaligned pointers in `@safe` code
    s1.ptr = null;
      ^
fail_compilation/test15399.d(49): Error: field `S2.ptr` cannot modify misaligned pointers in `@safe` code
    s2.ptr = null;
      ^
fail_compilation/test15399.d(50): Error: field `S1.ptr` cannot modify misaligned pointers in `@safe` code
    int** pp = &s1.ptr;
                  ^
fail_compilation/test15399.d(51): Error: field `S2.ptr` cannot modify misaligned pointers in `@safe` code
    pp = &s2.ptr;
            ^
fail_compilation/test15399.d(52): Error: field `S1.ptr` cannot modify misaligned pointers in `@safe` code
    bar(s1.ptr);
          ^
fail_compilation/test15399.d(53): Error: field `S2.ptr` cannot modify misaligned pointers in `@safe` code
    bar(s2.ptr);
          ^
fail_compilation/test15399.d(54): Error: field `S1.ptr` cannot modify misaligned pointers in `@safe` code
    sinister(s1.ptr);
               ^
fail_compilation/test15399.d(55): Error: field `S2.ptr` cannot modify misaligned pointers in `@safe` code
    sinister(s2.ptr);
               ^
---
*/

struct S1
{
        char c;
    align (1)
        int* ptr;
}

align (1)
struct S2
{
    int* ptr;
}

@safe void test(S1* s1, S2* s2)
{
    int* p = s1.ptr;
    p = s2.ptr;
    s1.ptr = null;
    s2.ptr = null;
    int** pp = &s1.ptr;
    pp = &s2.ptr;
    bar(s1.ptr);
    bar(s2.ptr);
    sinister(s1.ptr);
    sinister(s2.ptr);
    cbar(s1.ptr);
    cbar(s2.ptr);
}

@safe void bar(ref int*);
@safe void cbar(ref const int*);
@safe void sinister(out int*);
