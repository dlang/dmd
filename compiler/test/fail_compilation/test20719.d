/* TEST_OUTPUT:
---
fail_compilation/test20719.d(18): Error: struct `test20719.SumType` no size because of forward reference
fail_compilation/test20719.d(18):        while resolving `test20719.SumType`
fail_compilation/test20719.d(21):        while resolving `test20719.SumType.Storage`
       while resolving `test20719.SumType`
fail_compilation/test20719.d(37):        while resolving `test20719.isCopyable!(SumType).isCopyable`
fail_compilation/test20719.d(21):        error on member `test20719.SumType.storage`
fail_compilation/test20719.d(37): Error: variable `test20719.isCopyable!(SumType).__lambda_L37_C22.foo` - size of type `SumType` is invalid
fail_compilation/test20719.d(23): Error: template instance `test20719.isCopyable!(SumType)` error instantiating
---
*/
struct SumType
{
    alias Types = AliasSeq!(typeof(this));
    union Storage
    {
        Types[0] t;
    }

    Storage storage;

    static if (isCopyable!(Types[0])) {}
    static if (isAssignable!(Types[0])) {}
}

alias AliasSeq(TList...) = TList;

enum isAssignable(Rhs) = __traits(compiles, lvalueOf = rvalueOf!Rhs);

struct __InoutWorkaroundStruct {}

T rvalueOf(T)();

T lvalueOf()(__InoutWorkaroundStruct);

enum isCopyable(S) = { S foo; };
