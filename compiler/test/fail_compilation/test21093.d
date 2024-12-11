// https://issues.dlang.org/show_bug.cgi?id=21093
/*
TEST_OUTPUT:
---
fail_compilation/test21093.d(32): Error: function `test21093.LocalTime.hasDST` does not override any function
    override hasDST() { }
             ^
fail_compilation/test21093.d(40): Error: class `test21093.LocalTime2` cannot implicitly generate a default constructor when base class `test21093.TimeZone2` is missing a default constructor
class LocalTime2 : TimeZone2
^
fail_compilation/test21093.d(52): Error: function `test21093.LocalTime3.string` does not override any function
    override string () { }
             ^
fail_compilation/test21093.d(63): Error: cannot implicitly override base class method `test21093.TimeZone4.hasDST` with `test21093.LocalTime4.hasDST`; add `override` attribute
    bool hasDST() { }
         ^
---
*/

void fromUnixTime(immutable TimeZone tz = LocalTime()) { }
void fromUnixTime(immutable TimeZone2 tz = LocalTime2()) { }
void fromUnixTime(immutable TimeZone3 tz = LocalTime3()) { }
void fromUnixTime(immutable TimeZone4 tz = LocalTime4()) { }

class TimeZone
{
}

class LocalTime : TimeZone
{
    static immutable(LocalTime) opCall() { }
    override hasDST() { }
}

class TimeZone2
{
    this(string) { }
}

class LocalTime2 : TimeZone2
{
    static immutable(LocalTime2) opCall() { }
}

class TimeZone3
{
}

class LocalTime3 : TimeZone3
{
    static immutable(LocalTime3) opCall() { }
    override string () { }
}

class TimeZone4
{
    bool hasDST();
}

class LocalTime4 : TimeZone4
{
    static immutable(LocalTime4) opCall() { }
    bool hasDST() { }
}
