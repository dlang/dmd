/*
TEST_OUTPUT:
---
fail_compilation/diag10792.d(2): Error: semicolon expected following auto declaration, not 'EOF'
---
*/

#line 1
enum isPred(T) = asdf
