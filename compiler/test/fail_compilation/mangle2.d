/*
TEST_OUTPUT:
---
fail_compilation/mangle2.d(44): Error: pragma `mangle` char 0x20 not allowed in mangled name
__gshared pragma(mangle, "test 9") ubyte test9_1;
          ^
fail_compilation/mangle2.d(45): Error: pragma `mangle` char 0x20 not allowed in mangled name
__gshared extern pragma(mangle, "test 9") ubyte test9_1_e;
                 ^
fail_compilation/mangle2.d(48): Error: pragma `mangle` char 0x0a not allowed in mangled name
__gshared pragma(mangle, "test\n9") ubyte test9_2;
          ^
fail_compilation/mangle2.d(49): Error: pragma `mangle` char 0x0a not allowed in mangled name
__gshared extern pragma(mangle, "test\n9") ubyte test9_2_e;
                 ^
fail_compilation/mangle2.d(52): Error: pragma `mangle` char 0x07 not allowed in mangled name
__gshared pragma(mangle, "test\a9") ubyte test9_3;
          ^
fail_compilation/mangle2.d(53): Error: pragma `mangle` char 0x07 not allowed in mangled name
__gshared extern pragma(mangle, "test\a9") ubyte test9_3_e;
                 ^
fail_compilation/mangle2.d(56): Error: pragma `mangle` char 0x01 not allowed in mangled name
__gshared pragma(mangle, "test\x019") ubyte test9_4;
          ^
fail_compilation/mangle2.d(57): Error: pragma `mangle` char 0x01 not allowed in mangled name
__gshared extern pragma(mangle, "test\x019") ubyte test9_4_e;
                 ^
fail_compilation/mangle2.d(60): Error: pragma `mangle` char 0x00 not allowed in mangled name
__gshared pragma(mangle, "test\09") ubyte test9_5;
          ^
fail_compilation/mangle2.d(61): Error: pragma `mangle` char 0x00 not allowed in mangled name
__gshared extern pragma(mangle, "test\09") ubyte test9_5_e;
                 ^
fail_compilation/mangle2.d(64): Error: pragma `mangle` Outside Unicode code space
__gshared pragma(mangle, "test\xff9") ubyte test9_6;
          ^
fail_compilation/mangle2.d(65): Error: pragma `mangle` Outside Unicode code space
__gshared extern pragma(mangle, "test\xff9") ubyte test9_6_e;
                 ^
---
*/

//spaces
__gshared pragma(mangle, "test 9") ubyte test9_1;
__gshared extern pragma(mangle, "test 9") ubyte test9_1_e;

//\n chars
__gshared pragma(mangle, "test\n9") ubyte test9_2;
__gshared extern pragma(mangle, "test\n9") ubyte test9_2_e;

//\a chars
__gshared pragma(mangle, "test\a9") ubyte test9_3;
__gshared extern pragma(mangle, "test\a9") ubyte test9_3_e;

//\x01 chars
__gshared pragma(mangle, "test\x019") ubyte test9_4;
__gshared extern pragma(mangle, "test\x019") ubyte test9_4_e;

//\0 chars
__gshared pragma(mangle, "test\09") ubyte test9_5;
__gshared extern pragma(mangle, "test\09") ubyte test9_5_e;

//\xff chars
__gshared pragma(mangle, "test\xff9") ubyte test9_6;
__gshared extern pragma(mangle, "test\xff9") ubyte test9_6_e;
