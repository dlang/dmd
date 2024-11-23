/*
TEST_OUTPUT:
---
fail_compilation/fail153.d(12): Error: class `fail153.Bar` cannot inherit from class `Foo` because it is `final`
class Bar : Foo { }
^
---
*/

final class Foo { }

class Bar : Foo { }
