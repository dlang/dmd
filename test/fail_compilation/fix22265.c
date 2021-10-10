/* TEST_OUTPUT:
---
fail_compilation/fix22265.c(104): Error: cannot modify `const` expression `*buf`
fail_compilation/fix22265.c(105): Error: cannot modify `const` expression `p`
---
 */

// https://issues.dlang.org/show_bug.cgi?id=22265

#line 100

void test(const char *buf, char *const p)
{
   char a = *buf++;
   *buf = 'a';          // 104
   char b = *p++;       // 105
}
