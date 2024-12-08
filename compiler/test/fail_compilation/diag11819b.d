/*
TEST_OUTPUT:
---
fail_compilation/diag11819b.d(63): Error: unrecognized trait `HasMember`, did you mean `hasMember`?
    if (__traits(HasMember)) { }
        ^
fail_compilation/diag11819b.d(64): Error: unrecognized trait `Identifier`, did you mean `identifier`?
    if (__traits(Identifier)) { }
        ^
fail_compilation/diag11819b.d(65): Error: unrecognized trait `GetProtection`, did you mean `getProtection`?
    if (__traits(GetProtection)) { }
        ^
fail_compilation/diag11819b.d(66): Error: unrecognized trait `Parent`, did you mean `parent`?
    if (__traits(Parent)) { }
        ^
fail_compilation/diag11819b.d(67): Error: unrecognized trait `GetMember`, did you mean `getMember`?
    if (__traits(GetMember)) { }
        ^
fail_compilation/diag11819b.d(68): Error: unrecognized trait `GetOverloads`, did you mean `getOverloads`?
    if (__traits(GetOverloads)) { }
        ^
fail_compilation/diag11819b.d(69): Error: unrecognized trait `GetVirtualFunctions`, did you mean `getVirtualFunctions`?
    if (__traits(GetVirtualFunctions)) { }
        ^
fail_compilation/diag11819b.d(70): Error: unrecognized trait `GetVirtualMethods`, did you mean `getVirtualMethods`?
    if (__traits(GetVirtualMethods)) { }
        ^
fail_compilation/diag11819b.d(71): Error: unrecognized trait `ClassInstanceSize`, did you mean `classInstanceSize`?
    if (__traits(ClassInstanceSize)) { }
        ^
fail_compilation/diag11819b.d(72): Error: unrecognized trait `AllMembers`, did you mean `allMembers`?
    if (__traits(AllMembers)) { }
        ^
fail_compilation/diag11819b.d(73): Error: unrecognized trait `DerivedMembers`, did you mean `derivedMembers`?
    if (__traits(DerivedMembers)) { }
        ^
fail_compilation/diag11819b.d(74): Error: unrecognized trait `IsSame`, did you mean `isSame`?
    if (__traits(IsSame)) { }
        ^
fail_compilation/diag11819b.d(75): Error: unrecognized trait `Compiles`, did you mean `compiles`?
    if (__traits(Compiles)) { }
        ^
fail_compilation/diag11819b.d(76): Error: unrecognized trait `GetAliasThis`, did you mean `getAliasThis`?
    if (__traits(GetAliasThis)) { }
        ^
fail_compilation/diag11819b.d(77): Error: unrecognized trait `GetAttributes`, did you mean `getAttributes`?
    if (__traits(GetAttributes)) { }
        ^
fail_compilation/diag11819b.d(78): Error: unrecognized trait `GetFunctionAttributes`, did you mean `getFunctionAttributes`?
    if (__traits(GetFunctionAttributes)) { }
        ^
fail_compilation/diag11819b.d(79): Error: unrecognized trait `GetUnitTests`, did you mean `getUnitTests`?
    if (__traits(GetUnitTests)) { }
        ^
fail_compilation/diag11819b.d(80): Error: unrecognized trait `GetVirtualIndex`, did you mean `getVirtualIndex`?
    if (__traits(GetVirtualIndex)) { }
        ^
---
*/

void main()
{
    if (__traits(HasMember)) { }
    if (__traits(Identifier)) { }
    if (__traits(GetProtection)) { }
    if (__traits(Parent)) { }
    if (__traits(GetMember)) { }
    if (__traits(GetOverloads)) { }
    if (__traits(GetVirtualFunctions)) { }
    if (__traits(GetVirtualMethods)) { }
    if (__traits(ClassInstanceSize)) { }
    if (__traits(AllMembers)) { }
    if (__traits(DerivedMembers)) { }
    if (__traits(IsSame)) { }
    if (__traits(Compiles)) { }
    if (__traits(GetAliasThis)) { }
    if (__traits(GetAttributes)) { }
    if (__traits(GetFunctionAttributes)) { }
    if (__traits(GetUnitTests)) { }
    if (__traits(GetVirtualIndex)) { }
}
