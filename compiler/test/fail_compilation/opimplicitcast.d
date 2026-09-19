// REQUIRED_ARGS: -o-

/*
TEST_OUTPUT:
---
fail_compilation/opimplicitcast.d(18): Error: cannot implicitly convert expression `s` of type `NoCastStruct` to `int`
---
*/
// No matching opImplicitCast
struct NoCastStruct
{
    int value;
}

void testNoCast()
{
    NoCastStruct s;
    int x = s;
}

/*
TEST_OUTPUT:
---
fail_compilation/opimplicitcast.d(45): Error: template instance `opimplicitcast.WrongReturnStruct.opImplicitCast!int` does not match template declaration `opImplicitCast(T)()`
  with `T = int`
  must satisfy the following constraint:
`       __traits(isSame, T, string)`
fail_compilation/opimplicitcast.d(45): Error: cannot implicitly convert expression `s` of type `WrongReturnStruct` to `int`
---
*/
// opImplicitCast with wrong constraint
struct WrongReturnStruct
{
    int value;

    T opImplicitCast(T)() if (__traits(isSame, T, string))
    {
        return "hello";
    }
}

void testWrongReturn()
{
    WrongReturnStruct s;
    int x = s;
}

/*
TEST_OUTPUT:
---
fail_compilation/opimplicitcast.d(63): Error: cannot implicitly convert expression `c` of type `opimplicitcast.NoCastClass` to `int`
---
*/
// Class without opImplicitCast
class NoCastClass
{
    int value;
}

void testClassNoCast()
{
    NoCastClass c = new NoCastClass();
    int x = c;
}

/*
TEST_OUTPUT:
---
fail_compilation/opimplicitcast.d(79): Error: undefined identifier `NonExistent`
fail_compilation/opimplicitcast.d(86): Error: template instance `opimplicitcast.ErrorCastStruct.opImplicitCast!int` error instantiating
fail_compilation/opimplicitcast.d(86): Error: cannot implicitly convert expression `s` of type `ErrorCastStruct` to `int`
---
*/
// opImplicitCast with semantic error
struct ErrorCastStruct
{
    T opImplicitCast(T)() if (__traits(isSame, T, int))
    {
        return NonExistent.value;
    }
}

void testErrorCast()
{
    ErrorCastStruct s;
    int x = s;
}

/*
TEST_OUTPUT:
---
fail_compilation/opimplicitcast.d(113): Error: template instance `opimplicitcast.NoMatchStruct.opImplicitCast!string` does not match template declaration `opImplicitCast(T)()`
  with `T = string`
  must satisfy the following constraint:
`       __traits(isSame, T, int)`
fail_compilation/opimplicitcast.d(113): Error: cannot implicitly convert expression `s` of type `NoMatchStruct` to `string`
---
*/
// opImplicitCast exists but not for requested type
struct NoMatchStruct
{
    int value;

    T opImplicitCast(T)() if (__traits(isSame, T, int))
    {
        return value;
    }
}

void testNoMatch()
{
    NoMatchStruct s;
    string x = s;
}
