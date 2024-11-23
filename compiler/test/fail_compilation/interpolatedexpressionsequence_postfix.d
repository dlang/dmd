/* TEST_OUTPUT:
---
fail_compilation/interpolatedexpressionsequence_postfix.d(16): Error: String postfixes on interpolated expression sequences are not allowed.
    auto c = i"foo"c;
             ^
fail_compilation/interpolatedexpressionsequence_postfix.d(17): Error: String postfixes on interpolated expression sequences are not allowed.
    auto w = i"foo"w;
             ^
fail_compilation/interpolatedexpressionsequence_postfix.d(18): Error: String postfixes on interpolated expression sequences are not allowed.
    auto d = i"foo"d;
             ^
---
*/
void main() {
    // all postfixes are banned
    auto c = i"foo"c;
    auto w = i"foo"w;
    auto d = i"foo"d;
}
