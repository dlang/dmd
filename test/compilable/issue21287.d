// https://issues.dlang.org/show_bug.cgi?id=21287

struct A {}

alias canMatch(alias handler) = (A arg) => handler(arg);

struct StructuralSumType
{
    void opDispatch()
    {
        void fun(Value)(Value _) {}
        alias lambda = (_) {};

        alias ok = canMatch!lambda;
        alias err = canMatch!fun;
    }
}
