/* TEST_OUTPUT:
---
fail_compilation/test23225.i(11): Error: `0x` isn't a valid integer literal, use `0x0` instead
fail_compilation/test23225.i(11): Error: unterminated string constant starting at fail_compilation/test23225.i(11)
fail_compilation/test23225.i(11): Error: empty character constant
fail_compilation/test23225.i(14): Error: `0b` isn't a valid integer literal, use `0b0` instead
fail_compilation/test23225.i(14): Error: unterminated string constant starting at fail_compilation/test23225.i(14)
fail_compilation/test23225.i(14): Error: empty character constant
fail_compilation/test23225.i(18): Error: `=`, `;` or `,` expected to end declaration instead of `2`
---
*/

// https://github.com/dlang/dmd/issues/23225
// C23 6.4.4.2 — `'` after a base prefix is not a digit separator;
// it begins a character constant (N3220 6.4.4.2 EXAMPLE 1 style).

#line 11
int a = 0x'FF;

#line 14
int b = 0b'1;

// Adjacent character constant and digit do not form an integer
#line 18
int c = '1'2;
