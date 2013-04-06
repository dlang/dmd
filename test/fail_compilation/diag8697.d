/*
TEST_OUTPUT:
---
fail_compilation/diag8697.d(12): Error: no property 'Invalid' for type 'diag8697.Base'
fail_compilation/diag8697.d(12): Error: Base.Invalid is used as a type
---
*/

interface InterBase : InterRoot { }
class Base : InterBase { }

void test(Base.Invalid) { }

interface InterRoot { }
