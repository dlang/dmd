/*
TEST_OUTPUT:
---
fail_compilation/issue18077.d(20): Error: union `issue18077.SumType!(Scope, Return).Storage` no size because of forward reference
fail_compilation/issue18077.d(29): Error: template instance `issue18077.SumType!(Scope, Return)` error instantiating
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
