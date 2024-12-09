/*
TEST_OUTPUT:
---
fail_compilation/lexer4.d(46): Error: unterminated character constant
fail_compilation/lexer4.d(48): Error: unterminated character constant
static c2 = '';
            ^
fail_compilation/lexer4.d(49): Error: unterminated character constant
static c3 = 'a;
            ^
fail_compilation/lexer4.d(50): Error: binary digit expected, not `2`
int i = 0b12;
        ^
fail_compilation/lexer4.d(51): Error: octal digit expected, not `8`
int j = 0128;
        ^
fail_compilation/lexer4.d(51): Error: octal literals larger than 7 are no longer supported
int j = 0128;
        ^
fail_compilation/lexer4.d(52): Error: decimal digit expected, not `a`
int k = 12a;
        ^
fail_compilation/lexer4.d(53): Error: repeated integer suffix `U`
int l = 12UU;
        ^
fail_compilation/lexer4.d(54): Error: exponent required for hex float
int f = 0x1234.0;
        ^
fail_compilation/lexer4.d(55): Error: lower case integer suffix 'l' is not allowed. Please use 'L' instead
int m = 12l;
        ^
fail_compilation/lexer4.d(56): Error: use 'i' suffix instead of 'I'
static n = 12.1I;
           ^
fail_compilation/lexer4.d(58): Error: line number `1234567891234567879` out of range
#line 1234567891234567879
      ^
fail_compilation/lexer4.d(60): Error: positive integer argument expected following `#line`
#line whatever
      ^
fail_compilation/lexer4.d(19): Error: found `"file"` when expecting new line following `#line` directive
---
*/


static c1 = '
;
static c2 = '';
static c3 = 'a;
int i = 0b12;
int j = 0128;
int k = 12a;
int l = 12UU;
int f = 0x1234.0;
int m = 12l;
static n = 12.1I;

#line 1234567891234567879

#line whatever

#line 18 __FILE__

#line 20 "file" "file"

/** asdf *//** asdf2 */
int o;
