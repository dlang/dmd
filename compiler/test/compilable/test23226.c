/* https://github.com/dlang/dmd/issues/23226
 * C23 6.7.12: message operand of _Static_assert is optional.
 */

// C23 6.7.12 — single-argument form
_Static_assert(1);

// C23 6.7.12 — two-argument form (parity with existing C11 support)
_Static_assert(1, "ok");
