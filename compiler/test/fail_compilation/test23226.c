/* TEST_OUTPUT:
---
fail_compilation/test23226.c(10): Error: static assert:  `0` is false
---
*/

/* https://github.com/dlang/dmd/issues/23226
 * C23 6.7.12: failing single-argument _Static_assert still diagnoses.
 */
_Static_assert(0);
