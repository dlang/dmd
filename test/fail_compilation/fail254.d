/*
TEST_OUTPUT:
---
fail_compilation/fail254.d(27): Error: integer overflow
fail_compilation/fail254.d(27): Error: integer overflow
fail_compilation/fail254.d(27): Error: integer overflow
fail_compilation/fail254.d(27): Error: integer overflow
fail_compilation/fail254.d(27): Error: integer overflow
fail_compilation/fail254.d(27): Error: integer overflow
fail_compilation/fail254.d(27): Error: integer overflow
fail_compilation/fail254.d(27): Error: integer overflow
fail_compilation/fail254.d(27): Error: integer overflow
fail_compilation/fail254.d(27): Error: integer overflow
fail_compilation/fail254.d(27): Error: integer overflow
fail_compilation/fail254.d(27): Error: integer overflow
fail_compilation/fail254.d(27): Error: integer overflow
fail_compilation/fail254.d(27): Error: integer overflow
fail_compilation/fail254.d(27): Error: integer overflow
fail_compilation/fail254.d(27): Error: integer overflow
fail_compilation/fail254.d(28): Error: integer overflow
fail_compilation/fail254.d(29): Error: integer overflow
fail_compilation/fail254.d(30): Error: integer overflow
fail_compilation/fail254.d(31): Error: integer overflow
---
*/

ulong v1 = 0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
ulong v2 = 0x1_0000_0000_0000_0000;
ulong v3 = 0x1_FFFF_FFFF_FFFF_FFFF;
ulong v4 = 0x7_FFFF_FFFF_FFFF_FFFF;
ulong v5 = 0x1_0000_FFFF_FFFF_FFFF;
