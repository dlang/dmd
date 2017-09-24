// EXTRA_SOURCES: imports/test5230a.d
// https://issues.dlang.org/show_bug.cgi?id=5230

import imports.test5230a;

class Derived : Base
{
    override int method()
    {
        return 69;
    }
}
