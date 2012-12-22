/*
TEST_OUTPUT:
---
fail_compilation/diag3969.d(3): Error: Operator specialization is empty in opUnary operator
fail_compilation/diag3969.d(4): Error: Unrecognized opUnary operator: a
fail_compilation/diag3969.d(6): Error: Operator specialization is empty in opBinary operator
fail_compilation/diag3969.d(7): Error: cannot use opBinary for equality checks, use opEquals instead
fail_compilation/diag3969.d(8): Error: cannot use opBinary for equality checks, use opEquals instead
fail_compilation/diag3969.d(9): Error: cannot use opBinary for assignment, use opAssign instead
fail_compilation/diag3969.d(10): Error: Unrecognized opBinary operator: a
fail_compilation/diag3969.d(12): Error: Operator specialization is empty in opBinaryRight operator
fail_compilation/diag3969.d(13): Error: cannot use opBinaryRight for equality checks, use opEquals instead
fail_compilation/diag3969.d(14): Error: cannot use opBinaryRight for equality checks, use opEquals instead
fail_compilation/diag3969.d(15): Error: cannot use opBinaryRight for assignment, use opAssign instead
fail_compilation/diag3969.d(16): Error: Unrecognized opBinaryRight operator: a
---
*/

#line 1
struct F
{
    F opUnary(string op : "")() { return this; }
    F opUnary(string op : "a")() { return this; }

    bool opBinary(string op : "")(const ref S s) { return true; } ;
    bool opBinary(string op : "==")(const ref S s) { return true; } ;
    bool opBinary(string op : "!=")(const ref S s) { return true; } ;
    bool opBinary(string op : "=")(const ref S s) { return true; } ;
    bool opBinary(string op : "a")(const ref S s) { return true; } ;

    bool opBinaryRight(string op : "")(const ref S s) { return true; } ;
    bool opBinaryRight(string op : "==")(const ref S s) { return true; } ;
    bool opBinaryRight(string op : "!=")(const ref S s) { return true; } ;
    bool opBinaryRight(string op : "=")(const ref S s) { return true; } ;
    bool opBinaryRight(string op : "a")(const ref S s) { return true; } ;
}
