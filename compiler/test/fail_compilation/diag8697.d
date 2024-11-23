/*
TEST_OUTPUT:
---
fail_compilation/diag8697.d(15): Error: no property `Invalid` for type `diag8697.Base`
void test(Base.Invalid) { }
     ^
fail_compilation/diag8697.d(13):        class `Base` defined here
class Base : InterBase { }
^
---
*/
interface InterBase : InterRoot { }
class Base : InterBase { }

void test(Base.Invalid) { }

interface InterRoot { }
