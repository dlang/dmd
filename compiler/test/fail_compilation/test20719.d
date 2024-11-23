/* TEST_OUTPUT:
---
fail_compilation/test20719.d(19): Error: struct `test20719.SumType` no size because of forward reference
        Types[0] t;
                 ^
fail_compilation/test20719.d(38): Error: variable `test20719.isCopyable!(SumType).__lambda_L38_C22.foo` - size of type `SumType` is invalid
enum isCopyable(S) = { S foo; };
                         ^
fail_compilation/test20719.d(24): Error: template instance `test20719.isCopyable!(SumType)` error instantiating
    static if (isCopyable!(Types[0])) {}
               ^
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
