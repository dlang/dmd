/*
TEST_OUTPUT:
---
fail_compilation/ctfe10989.d(11): Error: Uncaught CTFE exception object.Exception("abc"c)
fail_compilation/ctfe10989.d(14):        called from here: throwing()
fail_compilation/ctfe10989.d(14):        while evaluating: static assert(throwing())
---
*/
int throwing() 
{
        throw new Exception(['a','b','c']); 
        return 0; 
}
static assert(throwing());
