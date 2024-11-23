/*
TEST_OUTPUT:
---
fail_compilation/fail254.d(22): Error: integer overflow
ulong v1 = 0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
           ^
fail_compilation/fail254.d(23): Error: integer overflow
ulong v2 = 0x1_0000_0000_0000_0000;
           ^
fail_compilation/fail254.d(24): Error: integer overflow
ulong v3 = 0x1_FFFF_FFFF_FFFF_FFFF;
           ^
fail_compilation/fail254.d(25): Error: integer overflow
ulong v4 = 0x7_FFFF_FFFF_FFFF_FFFF;
           ^
fail_compilation/fail254.d(26): Error: integer overflow
ulong v5 = 0x1_0000_FFFF_FFFF_FFFF;
           ^
---
*/

ulong v1 = 0xFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
ulong v2 = 0x1_0000_0000_0000_0000;
ulong v3 = 0x1_FFFF_FFFF_FFFF_FFFF;
ulong v4 = 0x7_FFFF_FFFF_FFFF_FFFF;
ulong v5 = 0x1_0000_FFFF_FFFF_FFFF;
