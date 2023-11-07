/* TEST_OUTPUT:
---
fail_compilation/test10910.d(103): Error: string index 17 is out of bounds `[0 .. 6]`
fail_compilation/test10910.d(104): Error: string index 12 is out of bounds `[0 .. 3]`
fail_compilation/test10910.d(105): Error: string index 9 is out of bounds `[0 .. 4]`
---
 */

// https://issues.dlang.org/show_bug.cgi?id=10910

#line 100

void example()
{
   char c = "abcdef"[17];
   char[7] x = "abc"[12];
   int ww = "abc"["afds"[9]];
}
