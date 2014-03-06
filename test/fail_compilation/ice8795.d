/*
TEST_OUTPUT:
---
fail_compilation/ice8795.d-mixin-13(13): Error: found 'EOF' when expecting '('
fail_compilation/ice8795.d-mixin-13(13): Error: expression expected, not 'EOF'
fail_compilation/ice8795.d-mixin-13(13): Error: found 'EOF' when expecting ')'
fail_compilation/ice8795.d-mixin-13(13): Error: found 'EOF' instead of statement
fail_compilation/ice8795.d-mixin-14(14): Error: anonymous classes not allowed
---
*/
void main()
{
    mixin("switch");
    mixin("interface;");
}
