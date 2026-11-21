// Test that omitting the trailing semicolon or comma on the final variant
// immediately before the closing right curly brace is accepted without error.

enum union SingleLineOmitted
{
    case First(), Second(), int, Tuple(int, int)
}

enum union MultiLineOmitted
{
    case First();
    case Second();
    case int;
    case Tuple(int, int)
}

enum union CommaSeparatedMultiLineOmitted
{
    case First(),
         Second(),
         int,
         Tuple(int, int)
}

void test()
{
    SingleLineOmitted s = SingleLineOmitted.First();
    MultiLineOmitted m = MultiLineOmitted.Second();
    CommaSeparatedMultiLineOmitted c = CommaSeparatedMultiLineOmitted.Tuple(1, 2);

    assert(s.__tag == 0);
    assert(m.__tag == 1);
    assert(c.__tag == 3);
}
