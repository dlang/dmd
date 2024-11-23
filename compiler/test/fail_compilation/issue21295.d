/*
TEST_OUTPUT:
---
fail_compilation/issue21295.d(10): Error: undefined identifier `Visitor`
Visitor should_fail;
        ^
---
*/
import imports.issue21295ast_node;
Visitor should_fail;
