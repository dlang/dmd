/*
TEST_OUTPUT:
---
fail_compilation/issue18077.d(31): Error: cannot use non-constant CTFE pointer in an initializer `new SumType!(Scope, Return)(Storage(Scope(null), ))`
---
*/

// https://github.com/dlang/dmd/issues/18077

enum isHashable(T) = __traits(compiles, T.init.tupleof[0][0].sizeof);

struct SumType(Types...)
{
    union Storage
    {
        Types values;
    }

    Storage storage;

    static if (isHashable!(Types[0])) {}
}

string[] toLines(Expression val) {
    return [];
}

alias Expression = SumType!(Scope, Return);

struct Return {
    Expression* _expr = new Expression;
}

struct Scope {
    Expression[] statements;

    string[] toLines() {
        return Expression.init.toLines;
    }
}
