// REQUIRED_ARGS: -unittest
module traits_getUnitTests;

template Tuple (T...)
{
    alias Tuple = T;
}

int i;

unittest
{
    i++;
}

void test_getUnitTestsFromModule ()
{
   static assert(__traits(getUnitTests, mixin(__MODULE__)).length == 1);
}

struct SGetUnitTestsFromAggregate
{
    unittest {}
}

class CGetUnitTestsFromAggregate
{
    unittest {}
}

void test_getUnitTestsFromAggregate ()
{
    static assert(__traits(getUnitTests, SGetUnitTestsFromAggregate).length == 1);
    static assert(__traits(getUnitTests, CGetUnitTestsFromAggregate).length == 1);
}

void test_callUnitTestFunction ()
{
    __traits(getUnitTests, mixin(__MODULE__))[0]();
    assert(i == 2); // 2, because the standard unit test runner
                    // will call the unit test function as well
}

struct GetUnitTestsWithUDA
{
   @("asd") unittest {}
}

void test_getUnitTestsWithUDA ()
{
    alias tests = Tuple!(__traits(getUnitTests, GetUnitTestsWithUDA));
    static assert(tests.length == 1);
    static assert(__traits(getAttributes, tests[0]).length == 1);
}

void main ()
{
    test_getUnitTestsFromModule();
    test_getUnitTestsFromAggregate();
    test_callUnitTestFunction();
    test_getUnitTestsWithUDA();
}