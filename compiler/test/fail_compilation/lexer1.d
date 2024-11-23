/*
TEST_OUTPUT:
---
fail_compilation/lexer1.d(74): Error: declaration expected, not `x"01 02 03"w`
x"01 02 03"w;
^
fail_compilation/lexer1.d(75): Error: declaration expected, not `2147483649U`
0x80000001;
^
fail_compilation/lexer1.d(76): Error: declaration expected, not `0.1`
0.1;
^
fail_compilation/lexer1.d(77): Error: declaration expected, not `0.1f`
0.1f;
^
fail_compilation/lexer1.d(78): Error: declaration expected, not `0.1L`
0.1L;
^
fail_compilation/lexer1.d(79): Error: declaration expected, not `0.1i`
0.1i;
^
fail_compilation/lexer1.d(80): Error: declaration expected, not `0.1fi`
0.1fi;
^
fail_compilation/lexer1.d(81): Error: declaration expected, not `0.1Li`
0.1Li;
^
fail_compilation/lexer1.d(82): Error: declaration expected, not `' '`
' ';
^
fail_compilation/lexer1.d(83): Error: declaration expected, not `'\ud7ff'`
'\uD7FF';
^
fail_compilation/lexer1.d(84): Error: declaration expected, not `'\U00010000'`
'\U00010000';
^
fail_compilation/lexer1.d(85): Error: declaration expected, not `"ab\\c\"\u1234a\U00011100a\0ab"d`
"ab\\c\"\u1234a\U00011100a\000ab"d;
^
fail_compilation/lexer1.d(87): Error: declaration expected, not `module`
module x;
^
fail_compilation/lexer1.d(89): Error: escape hex sequence has 1 hex digits instead of 2
static s1 = "\x1G";
            ^
fail_compilation/lexer1.d(90): Error: undefined escape hex sequence \xG
static s2 = "\xGG";
            ^
fail_compilation/lexer1.d(91): Error: unnamed character entity &unnamedentity;
static s3 = "\&unnamedentity;";
            ^
fail_compilation/lexer1.d(92): Error: unterminated named entity &1;
static s4 = "\&1";
            ^
fail_compilation/lexer1.d(93): Error: unterminated named entity &*;
static s5 = "\&*";
            ^
fail_compilation/lexer1.d(94): Error: unterminated named entity &s1";
static s6 = "\&s1";
            ^
fail_compilation/lexer1.d(95): Error: unterminated named entity &2;
static s7 = "\&2;";
            ^
fail_compilation/lexer1.d(96): Error: escape octal sequence \400 is larger than \377
static s7 = "\400;";
            ^
fail_compilation/lexer1.d(97): Error: html entity requires 2 code units, use a string instead of a character
dchar s8 = '\&acE;';
           ^
---
*/

// https://dlang.dawg.eu/coverage/src/lexer.c.gcov.html
x"01 02 03"w;
0x80000001;
0.1;
0.1f;
0.1L;
0.1i;
0.1fi;
0.1Li;
' ';
'\uD7FF';
'\U00010000';
"ab\\c\"\u1234a\U00011100a\000ab"d;

module x;

static s1 = "\x1G";
static s2 = "\xGG";
static s3 = "\&unnamedentity;";
static s4 = "\&1";
static s5 = "\&*";
static s6 = "\&s1";
static s7 = "\&2;";
static s7 = "\400;";
dchar s8 = '\&acE;';
