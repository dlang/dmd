
import std.meta;

enum Enum
{
    withoutUda,
    @("first") valueWithUda,
    @("second", "extra", 3) secondValueWithUda,
}

@("outter")
enum
{
    @("first") anonFirst,
    anonSecond,
    @("third") @("extra") anonThird,
}

static assert(__traits(getAttributes, Enum.withoutUda).length == 0);
static assert(__traits(getAttributes, Enum.valueWithUda) == AliasSeq!("first"));
static assert(__traits(getAttributes, Enum.secondValueWithUda) == AliasSeq!("second", "extra", 3));

static assert(__traits(getAttributes, anonFirst) == AliasSeq!("outter", "first"));
static assert(__traits(getAttributes, anonSecond) == AliasSeq!("outter"));
static assert(__traits(getAttributes, anonThird) == AliasSeq!("outter", "third", "extra"));
