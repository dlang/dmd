/*
TEST_OUTPUT:
---
fail_compilation/diag21883.d(17): Error: `diag21883.ClassB`: base class must be specified first, before any interfaces.
class ClassB: InterfaceA, ClassA {
^
---
*/
// https://issues.dlang.org/show_bug.cgi?id=21883

interface InterfaceA {
}

class ClassA {
}

class ClassB: InterfaceA, ClassA {
}
