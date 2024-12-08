/*
TEST_OUTPUT:
---
fail_compilation/fail14009.d(14): Error: expression expected not `:`
      mov EAX, FS: 1 ? 2 : : 3;   // rejected
                              ^
---
*/

void main()
{
    asm {
      mov EAX, FS: 1 ? 2 : 3;     // accepted
      mov EAX, FS: 1 ? 2 : : 3;   // rejected
    }
}
